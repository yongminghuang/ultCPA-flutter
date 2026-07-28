import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/network/app_api_client.dart';
import 'package:ultcpa_flutter/src/practice/practice_benefit_kind.dart';
import 'package:ultcpa_flutter/src/storage/legacy_app_state_store.dart';
import 'package:ultcpa_flutter/src/vip_purchase/big_skill_practice_purchase_success_repository.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_purchase_models.dart';

void main() {
  group('big-skill success summary repository', () {
    test(
      'prefers one live benefit request in the current snapshot scope',
      () async {
        final api = _Api((request) {
          expect(request.method, 'GET');
          expect(request.path, '/app/user/getUserBenefits');
          expect(request.query, isNull);
          return const [
            {
              'category': 'joy-ledger',
              'benefitsCode': 'KJ_PRACTICE_CHAPTER_L2_3M',
              'benefitsDesc': ' 实时章节包 ',
              'expireTime': '2026-08-01',
            },
          ];
        });
        final store = _Store(
          _snapshot(
            userBenefitsJson: jsonEncode(const [
              {
                'category': 'joy-ledger',
                'benefitsCode': 'KJ_PRACTICE_CHAPTER_L2_3M',
                'benefitsDesc': '缓存章节包',
                'expireTime': '2026-09-01',
              },
            ]),
          ),
        );
        final repository = BigSkillPracticePurchaseSuccessRepository(
          api: api,
          stateStore: store,
          now: () => DateTime(2026, 7, 17, 12),
        );

        final summary = await repository.loadSummary(
          PracticeBenefitKind.chapterPractice,
        );

        expect(summary.title, '恭喜！【实时章节包】开通成功');
        expect(summary.expiresOn, '2026-08-01');
        expect(store.reads, 1);
        expect(api.requests, hasLength(1));
      },
    );

    test(
      'uses cached benefits when live refresh fails or is not a list',
      () async {
        final handlers = <FutureOr<Object?> Function(_Request)>[
          (_) => throw const AppApiException('offline'),
          (_) => null,
          (_) => const <String, Object?>{},
          (_) => 'bad body',
        ];
        for (final handler in handlers) {
          final api = _Api(handler);
          final repository = BigSkillPracticePurchaseSuccessRepository(
            api: api,
            stateStore: _Store(
              _snapshot(
                userBenefitsJson: jsonEncode(const [
                  {
                    'category': 'joy-ledger',
                    'benefitsCode': 'KJ_PRACTICE_PAST_EXAMS_L2_3M',
                    'benefitsDesc': '缓存真题包',
                    'expireTime': '2026-08-01',
                  },
                ]),
              ),
            ),
            now: () => DateTime(2026, 7, 17, 12),
          );

          final summary = await repository.loadSummary(
            PracticeBenefitKind.pastExams,
          );

          expect(summary.title, '恭喜！【缓存真题包】开通成功');
          expect(summary.expiresOn, '2026-08-01');
          expect(api.requests, hasLength(1));
          expect(api.requests.single.query, isNull);
        }
      },
    );

    test(
      'returns the kind fallback for malformed snapshot and cache',
      () async {
        final malformedSnapshot = BigSkillPracticePurchaseSuccessRepository(
          api: _Api((_) => throw StateError('must not call')),
          stateStore: _Store(const {'selectedCategoryJson': '{bad json'}),
        );
        final malformedCache = BigSkillPracticePurchaseSuccessRepository(
          api: _Api((_) => const <String, Object?>{}),
          stateStore: _Store(_snapshot(userBenefitsJson: '{bad json')),
        );

        expect(
          await malformedSnapshot.loadSummary(PracticeBenefitKind.fastPractice),
          const BigSkillPracticePurchaseSuccessSummary.generic(
            PracticeBenefitKind.fastPractice,
          ),
        );
        expect(
          await malformedCache.loadSummary(PracticeBenefitKind.regularPractice),
          const BigSkillPracticePurchaseSuccessSummary.generic(
            PracticeBenefitKind.regularPractice,
          ),
        );
      },
    );
  });

  group('big-skill practice destination repository', () {
    test('uses valid cached modules without state or network reads', () async {
      const practice = HomeModule(
        id: 41,
        name: '技巧练题',
        page: 'unknown',
        tag: '',
      );
      const circle = HomeModule(
        id: 42,
        name: '大招圈题卷',
        page: 'unknown',
        tag: '',
      );
      final api = _Api((_) => throw StateError('must not call'));
      final store = _Store(_snapshot());
      final repository = BigSkillPracticePurchaseSuccessRepository(
        api: api,
        stateStore: store,
      );

      final destination = await repository.loadDestination(
        cachedPracticeModule: practice,
        cachedCircleModule: circle,
      );

      expect(destination, isNotNull);
      expect(destination!.practiceModule, same(practice));
      expect(destination.circleModule, same(circle));
      expect(store.reads, 0);
      expect(api.requests, isEmpty);
    });

    test(
      'drops an invalid cached circle while keeping cached practice',
      () async {
        const practice = HomeModule(
          id: 41,
          name: '练题入口',
          page: '技巧练题',
          tag: '',
        );
        const invalidCircle = HomeModule(
          id: 0,
          name: '技巧圈题卷',
          page: '技巧圈题卷',
          tag: '',
        );
        final repository = BigSkillPracticePurchaseSuccessRepository(
          api: _Api((_) => throw StateError('must not call')),
          stateStore: _Store(_snapshot()),
        );

        final destination = await repository.loadDestination(
          cachedPracticeModule: practice,
          cachedCircleModule: invalidCircle,
        );

        expect(destination!.practiceModule, same(practice));
        expect(destination.circleModule, isNull);
      },
    );

    test(
      'loads the selected market and preserves first practice and circle',
      () async {
        final api = _Api((request) {
          expect(request.method, 'GET');
          expect(request.path, '/knowledge/shelf/moduleLis');
          expect(request.query, {'marketId': 88});
          return const [
            {'id': 0, 'name': '技巧练题', 'page': '技巧练题'},
            {
              'id': 51,
              'name': '圈题入口',
              'page': '技巧圈题卷',
              'tag': 'hot',
              'type': '结构化',
            },
            {
              'id': 52,
              'name': ' 技巧练题 ',
              'page': 'other',
              'tag': 'new',
              'type': '嵌套化',
            },
            {'id': 53, 'name': '后续练题', 'page': '技巧练题'},
            {'id': 54, 'name': '后续圈题', 'page': '技巧圈题卷'},
          ];
        });
        final store = _Store(_snapshot(selectedMarketId: 88));
        final repository = BigSkillPracticePurchaseSuccessRepository(
          api: api,
          stateStore: store,
        );

        final destination = await repository.loadDestination();

        expect(destination, isNotNull);
        expect(destination!.practiceModule.id, 52);
        expect(destination.practiceModule.name, '技巧练题');
        expect(destination.practiceModule.type, '嵌套化');
        expect(destination.circleModule!.id, 51);
        expect(destination.circleModule!.tag, 'hot');
        expect(store.reads, 1);
        expect(api.requests, hasLength(1));
      },
    );

    test('accepts the exact Android module names and pages', () async {
      const bodies = [
        [
          {'id': 61, 'name': '练题', 'page': '技巧练题'},
          {'id': 62, 'name': '技巧圈题卷', 'page': 'other'},
        ],
        [
          {'id': 63, 'name': '技巧练题', 'page': 'other'},
          {'id': 64, 'name': '大招圈题卷', 'page': 'other'},
        ],
      ];
      for (final body in bodies) {
        final repository = BigSkillPracticePurchaseSuccessRepository(
          api: _Api((_) => body),
          stateStore: _Store(_snapshot()),
        );

        final destination = await repository.loadDestination();

        expect(destination, isNotNull);
        expect(destination!.practiceModule.id, anyOf(61, 63));
        expect(destination.circleModule, isNotNull);
      }
    });

    test(
      'returns null for invalid market request body and missing practice',
      () async {
        final cases =
            <({Map<String, dynamic> snapshot, FutureOr<Object?> body})>[
              (snapshot: _snapshot(selectedMarketId: 0), body: const []),
              (snapshot: _snapshot(), body: const <String, Object?>{}),
              (snapshot: _snapshot(), body: 'bad body'),
              (
                snapshot: _snapshot(),
                body: const [
                  {'id': 71, 'name': '技巧圈题卷', 'page': '技巧圈题卷'},
                  {'id': 72, 'name': '推广技巧', 'page': '推广技巧'},
                ],
              ),
            ];
        for (final entry in cases) {
          final api = _Api((_) => entry.body);
          final repository = BigSkillPracticePurchaseSuccessRepository(
            api: api,
            stateStore: _Store(entry.snapshot),
          );

          expect(await repository.loadDestination(), isNull);
          expect(
            api.requests.length,
            entry.snapshot['selectedMarketId'] == 0 ? 0 : 1,
          );
        }

        final failed = BigSkillPracticePurchaseSuccessRepository(
          api: _Api((_) => throw const AppApiException('offline')),
          stateStore: _Store(_snapshot()),
        );
        expect(await failed.loadDestination(), isNull);
      },
    );
  });
}

Map<String, dynamic> _snapshot({
  int selectedMarketId = 6,
  String userBenefitsJson = '',
}) {
  return {
    'category': 'joy-ledger',
    'selectedLevel': '中级会计',
    'selectedMarketId': selectedMarketId,
    'selectedSubject': '会计实务',
    'userBenefitsJson': userBenefitsJson,
  };
}

final class _Request {
  const _Request({required this.method, required this.path, this.query});

  final String method;
  final String path;
  final Map<String, dynamic>? query;
}

final class _Api implements AppApiClient {
  _Api(this.handler);

  final FutureOr<Object?> Function(_Request request) handler;
  final requests = <_Request>[];

  @override
  Future<Object?> getBody(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final request = _Request(method: 'GET', path: path, query: queryParameters);
    requests.add(request);
    return await handler(request);
  }

  @override
  Future<Object?> postBody(String path, Map<String, dynamic> body) {
    throw StateError('unexpected POST $path');
  }
}

final class _Store implements LegacyAppStateStore {
  _Store(this.snapshot);

  final Map<String, dynamic> snapshot;
  int reads = 0;

  @override
  Future<Map<String, dynamic>> readAppSnapshot() async {
    reads += 1;
    return snapshot;
  }

  @override
  Future<void> persistCategorySelection({
    required String categoryBodyJson,
    required String category,
    required Map<String, dynamic> selectedCategory,
    required String selectedCategoryKey,
    required int marketId,
    required String subject,
  }) async {}
}
