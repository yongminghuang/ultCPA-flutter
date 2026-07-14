enum LegacyDomain { agreement, session, profile, preferences, learning, room }

final class LegacySnapshot {
  const LegacySnapshot(this.values);
  final Map<String, Object?> values;
}

abstract interface class LegacyMigrationBackend {
  Future<bool> isMigrated(LegacyDomain domain, int version);
  Future<void> begin(LegacyDomain domain);
  Future<LegacySnapshot> readLegacy(LegacyDomain domain);
  Future<void> writeNew(LegacyDomain domain, LegacySnapshot snapshot);
  Future<void> verify(LegacyDomain domain, LegacySnapshot snapshot);
  Future<void> commit(LegacyDomain domain, int version);
  Future<void> rollback(LegacyDomain domain);
}

final class LegacyMigrationReport {
  const LegacyMigrationReport({
    required this.migratedDomains,
    required this.skippedDomains,
    required this.failedDomains,
  });

  final List<LegacyDomain> migratedDomains;
  final List<LegacyDomain> skippedDomains;
  final List<LegacyDomain> failedDomains;
}

final class LegacyMigrationCoordinator {
  const LegacyMigrationCoordinator(this.backend);
  final LegacyMigrationBackend backend;

  Future<LegacyMigrationReport> migrate({required int version}) async {
    final migrated = <LegacyDomain>[];
    final skipped = <LegacyDomain>[];
    final failed = <LegacyDomain>[];

    for (final domain in LegacyDomain.values) {
      if (await backend.isMigrated(domain, version)) {
        skipped.add(domain);
        continue;
      }
      try {
        await backend.begin(domain);
        final snapshot = await backend.readLegacy(domain);
        await backend.writeNew(domain, snapshot);
        await backend.verify(domain, snapshot);
        await backend.commit(domain, version);
        migrated.add(domain);
      } catch (_) {
        try {
          await backend.rollback(domain);
        } catch (_) {
          // The domain remains unmarked and will be retried on next launch.
        }
        failed.add(domain);
      }
    }

    return LegacyMigrationReport(
      migratedDomains: List.unmodifiable(migrated),
      skippedDomains: List.unmodifiable(skipped),
      failedDomains: List.unmodifiable(failed),
    );
  }
}
