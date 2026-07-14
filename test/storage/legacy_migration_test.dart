import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/storage/legacy_migration.dart';

void main() {
  test('migrates each domain once and skips its version on rerun', () async {
    final backend = _FakeBackend();
    final coordinator = LegacyMigrationCoordinator(backend);

    final first = await coordinator.migrate(version: 1);
    final second = await coordinator.migrate(version: 1);

    expect(first.failedDomains, isEmpty);
    expect(first.migratedDomains, LegacyDomain.values);
    expect(second.skippedDomains, LegacyDomain.values);
    expect(backend.commits.length, LegacyDomain.values.length);
  });

  test('rolls back only the failing domain and continues', () async {
    final backend = _FakeBackend(failingDomain: LegacyDomain.learning);
    final report = await LegacyMigrationCoordinator(
      backend,
    ).migrate(version: 1);

    expect(report.failedDomains, [LegacyDomain.learning]);
    expect(backend.rollbacks, [LegacyDomain.learning]);
    expect(report.migratedDomains, contains(LegacyDomain.session));
    expect(report.migratedDomains, contains(LegacyDomain.room));
  });
}

final class _FakeBackend implements LegacyMigrationBackend {
  _FakeBackend({this.failingDomain});

  final LegacyDomain? failingDomain;
  final migrated = <(LegacyDomain, int)>{};
  final commits = <LegacyDomain>[];
  final rollbacks = <LegacyDomain>[];

  @override
  Future<bool> isMigrated(LegacyDomain domain, int version) async =>
      migrated.contains((domain, version));

  @override
  Future<void> begin(LegacyDomain domain) async {}

  @override
  Future<LegacySnapshot> readLegacy(LegacyDomain domain) async =>
      LegacySnapshot(<String, Object?>{'domain': domain.name});

  @override
  Future<void> writeNew(LegacyDomain domain, LegacySnapshot snapshot) async {
    if (domain == failingDomain) throw StateError('write failed');
  }

  @override
  Future<void> verify(LegacyDomain domain, LegacySnapshot snapshot) async {}

  @override
  Future<void> commit(LegacyDomain domain, int version) async {
    commits.add(domain);
    migrated.add((domain, version));
  }

  @override
  Future<void> rollback(LegacyDomain domain) async => rollbacks.add(domain);
}
