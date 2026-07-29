import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/network/app_api_client.dart';
import 'package:ultcpa_flutter/src/practice/practice_benefit_kind.dart';
import 'package:ultcpa_flutter/src/practice/practice_models.dart';
import 'package:ultcpa_flutter/src/practice/practice_repository.dart';
import 'package:ultcpa_flutter/src/practice/practice_review_store.dart';
import 'package:ultcpa_flutter/src/storage/legacy_app_state_store.dart';

void main() {
  group('module practice loading', () {
    test('request defaults regular and preserves success handoff metadata', () {
      const circle = HomeModule(id: 52, name: '技巧圈题卷', page: '技巧圈题卷', tag: '');
      const normal = ModulePracticeRequest(module: _flatModule);
      const explicit = ModulePracticeRequest(
        module: _flatModule,
        benefitKind: PracticeBenefitKind.pastExams,
        bigSkillCircleModule: circle,
      );

      expect(normal.benefitKind, PracticeBenefitKind.regularPractice);
      expect(normal.bigSkillCircleModule, isNull);
      expect(explicit.benefitKind, PracticeBenefitKind.pastExams);
      expect(explicit.bigSkillCircleModule, same(circle));
    });

    test('loads every declared flat page with the Android request', () async {
      final api = _Api((path, query) {
        expect(path, '/app/goods/pageGoodsData');
        return {
          'total': 2,
          'pages': 2,
          'current': query['pageNum'],
          'size': 30,
          'records': [_question('q-${query['pageNum']}')],
        };
      });
      final repository = PracticeRepository(
        api: api,
        stateStore: _Store({
          'skillQuestionFreeCount': '4',
          'isLoggedIn': false,
        }),
      );

      final catalog = await repository.load(
        const ModulePracticeRequest(module: _flatModule),
      );

      expect(api.getRequests.map((request) => request.query), [
        {'pageNum': 1, 'pageSize': 30, 'shelfId': 42},
        {'pageNum': 2, 'pageSize': 30, 'shelfId': 42},
      ]);
      expect(_questionIds(catalog), ['q-1', 'q-2']);
      expect(catalog.title, '技巧练题');
      expect(catalog.access.fullAccess, isFalse);
      expect(catalog.access.freeQuestionCount, 4);
    });

    test('uses the flat fallback for an unknown module type', () async {
      final api = _Api(
        (path, query) => {
          'records': [_question('q-1')],
        },
      );
      final repository = PracticeRepository(
        api: api,
        stateStore: _Store(const {}),
      );

      await repository.load(
        const ModulePracticeRequest(
          module: HomeModule(
            id: 43,
            name: '历史练题',
            page: '大招练题',
            tag: '',
            type: 'legacy',
          ),
        ),
      );

      expect(api.getRequests.single.query, {
        'pageNum': 1,
        'pageSize': 30,
        'shelfId': 43,
      });
    });

    test(
      'selects the first structured catalog chapter and pages one leaf',
      () async {
        final api = _Api((path, query) {
          if (path == '/app/shelf/getShelfTree') {
            return _singleLeafTree;
          }
          return {
            'records': [_question('q-structured')],
          };
        });
        final repository = PracticeRepository(
          api: api,
          stateStore: _Store(const {}),
        );

        final catalog = await repository.load(
          const ModulePracticeRequest(module: _structuredModule),
        );

        expect(api.getRequests, hasLength(2));
        expect(api.getRequests.first.path, '/app/shelf/getShelfTree');
        expect(api.getRequests.first.query, {'shelfId': 42});
        expect(api.getRequests.last.path, '/app/goods/pageGoodsData');
        expect(api.getRequests.last.query, {
          'pageNum': 1,
          'pageSize': 30,
          'modelId': 42,
          'shelfId': 111,
        });
        expect(_questionIds(catalog), ['q-structured']);
      },
    );

    test('loads all leaves in the first structured chapter together', () async {
      final api = _Api((path, query) {
        if (path == '/app/shelf/getShelfTree') return _multiLeafTree;
        expect(path, '/app/goods/listGoods');
        return [_question('q-1'), _question('q-2')];
      });
      final repository = PracticeRepository(
        api: api,
        stateStore: _Store(const {}),
      );

      final catalog = await repository.load(
        const ModulePracticeRequest(module: _structuredModule),
      );

      expect(api.getRequests.last.query, {
        'shelfIds': [111, 112],
      });
      expect(_questionIds(catalog), ['q-1', 'q-2']);
    });

    test('rejects an empty structured tree as invalid data', () async {
      final api = _Api((path, query) => const []);
      final repository = PracticeRepository(
        api: api,
        stateStore: _Store(const {}),
      );

      await expectLater(
        repository.load(const ModulePracticeRequest(module: _structuredModule)),
        throwsFormatException,
      );
    });
  });

  group('selected fast practice loading', () {
    test('loads every flat page and overlays the exact leaf records', () async {
      final api = _Api(
        (path, query) {
          expect(path, '/app/goods/pageGoodsData');
          return {
            'total': 2,
            'pages': 2,
            'current': query['pageNum'],
            'size': 30,
            'records': [_question(query['pageNum'] == 1 ? '101' : '102')],
          };
        },
        postResponder: (path, body) {
          expect(path, '/app/question/getQuestionRecordList');
          expect(body, {
            'modelId': 42,
            'shelfIdList': [111],
          });
          return const [
            {
              'shelfId': 111,
              'questionRecordResponseList': [
                {'questionId': 101, 'choose': 'b,a', 'isRight': 1},
                {'questionId': 102, 'choose': 'B', 'isRight': 0},
              ],
            },
          ];
        },
      );
      final repository = PracticeRepository(
        api: api,
        stateStore: _Store(const {'isLoggedIn': false}),
      );

      final catalog = await repository.load(_fastRequest);

      expect(api.getRequests.map((request) => request.path), [
        '/app/goods/pageGoodsData',
        '/app/goods/pageGoodsData',
      ]);
      expect(api.getRequests.map((request) => request.query), [
        {'pageNum': 1, 'pageSize': 30, 'shelfId': 111},
        {'pageNum': 2, 'pageSize': 30, 'shelfId': 111},
      ]);
      expect(api.postRequests, hasLength(1));
      expect(_questionIds(catalog), ['101', '102']);
      expect(catalog.title, '精选一');
      expect(catalog.access.fullAccess, isTrue);
      expect(catalog.access.freeQuestionCount, 0);
      expect(catalog.behavior, const PracticeBehavior.standard());
      expect(
        (catalog.items[0] as PracticeQuestionItem).question.serverAnswer,
        const PracticeAnswer(choose: 'AB', isRight: true),
      );
      expect(
        (catalog.items[1] as PracticeQuestionItem).question.serverAnswer,
        const PracticeAnswer(choose: 'B', isRight: false),
      );
    });

    test(
      'keeps leaf questions answerable when optional records fail',
      () async {
        final api = _Api(
          (path, query) => {
            'records': [_question('101')],
          },
          postResponder: (path, body) => throw StateError('records offline'),
        );
        final repository = PracticeRepository(
          api: api,
          stateStore: _Store(const {}),
        );

        final catalog = await repository.load(_fastRequest);

        expect(_questionIds(catalog), ['101']);
        expect(
          (catalog.items.single as PracticeQuestionItem).question.serverAnswer,
          isNull,
        );
        expect(catalog.access.fullAccess, isTrue);
      },
    );

    test('propagates a required leaf goods failure', () async {
      final repository = PracticeRepository(
        api: _Api((path, query) => throw StateError('goods offline')),
        stateStore: _Store(const {}),
      );

      await expectLater(repository.load(_fastRequest), throwsStateError);
    });

    test('rejects invalid module and leaf ids before network I/O', () async {
      final api = _Api((path, query) => throw StateError('unexpected GET'));
      final repository = PracticeRepository(
        api: api,
        stateStore: _Store(const {}),
      );

      await expectLater(
        repository.load(
          const FastPracticeRequest(
            module: HomeModule(id: 0, name: '速成300题', page: '速成300题', tag: ''),
            shelfId: 111,
            shelfName: '精选一',
            shelfType: '扁平化',
          ),
        ),
        throwsArgumentError,
      );
      await expectLater(
        repository.load(
          const FastPracticeRequest(
            module: _fastModule,
            shelfId: 0,
            shelfName: '精选一',
            shelfType: '扁平化',
          ),
        ),
        throwsArgumentError,
      );
      expect(api.getRequests, isEmpty);
      expect(api.postRequests, isEmpty);
    });
  });

  group('daily skill practice loading', () {
    test(
      'loads exact related questions with full access and no state read',
      () async {
        final api = _Api((path, query) {
          expect(path, '/app/question/queryQuestionsBySkill');
          expect(query, {'skillId': '11'});
          return [
            {..._question('101'), 'choose': 'B', 'isRight': false},
            _question('102'),
          ];
        });
        final repository = PracticeRepository(
          api: api,
          stateStore: _ThrowingStore(),
        );

        final catalog = await repository.load(_dailyRequest);

        expect(api.getRequests, hasLength(1));
        expect(api.postRequests, isEmpty);
        expect(_questionIds(catalog), ['101', '102']);
        expect(catalog.title, '每日一招');
        expect(catalog.access.fullAccess, isTrue);
        expect(catalog.access.freeQuestionCount, 0);
        expect(catalog.behavior.persistAnswers, isTrue);
        expect(
          catalog.items
              .whereType<PracticeQuestionItem>()
              .first
              .question
              .serverAnswer,
          isNull,
        );
      },
    );

    test('rejects invalid daily coordinates before any I/O', () async {
      final api = _Api((path, query) => throw StateError('unexpected GET'));
      final repository = PracticeRepository(
        api: api,
        stateStore: _Store(const {}),
      );

      for (final request in <DailySkillPracticeRequest>[
        const DailySkillPracticeRequest(
          module: HomeModule(id: 0, name: '每日一招', page: '每日一招', tag: ''),
          skillId: '11',
          shelfId: 111,
        ),
        const DailySkillPracticeRequest(
          module: _dailyModule,
          skillId: '',
          shelfId: 111,
        ),
        const DailySkillPracticeRequest(
          module: _dailyModule,
          skillId: '11',
          shelfId: 0,
        ),
      ]) {
        await expectLater(repository.load(request), throwsArgumentError);
      }
      expect(api.getRequests, isEmpty);
      expect(api.postRequests, isEmpty);
    });
  });

  group('skill and access loading', () {
    test('loads mnemonic-related questions by the exact skill id', () async {
      final api = _Api((path, query) {
        if (path == '/app/user/getUserBenefits') {
          return const [
            {
              'category': 'social-work',
              'benefitsCode': 'SW_MEMBER_L1_3M',
              'expireTime': '2026-12-31 23:59:59',
            },
          ];
        }
        return [_question('q-skill')];
      });
      final repository = PracticeRepository(
        api: api,
        stateStore: _Store(_loggedInSnapshot),
        now: () => DateTime(2026, 7, 16),
      );

      final catalog = await repository.load(
        const SkillPracticeRequest(
          skillId: 'skill-7',
          title: '关联练题',
          position: 2,
          module: _flatModule,
        ),
      );

      expect(api.getRequests.first.path, '/app/question/queryQuestionsBySkill');
      expect(api.getRequests.first.query, {'skillId': 'skill-7'});
      expect(catalog.title, '关联练题');
      expect(catalog.access.fullAccess, isTrue);
      expect(_questionIds(catalog), ['q-skill']);
    });

    test(
      'regular practice accepts practice_skill but skill relation does not',
      () async {
        final api = _Api((path, query) {
          if (path == '/app/user/getUserBenefits') {
            return const [
              {
                'benefitsCode': 'social-work:初级社工:社工实务:practice_skill',
                'expireTime': '2026-12-31',
              },
            ];
          }
          if (path == '/app/question/queryQuestionsBySkill') {
            return [_question('q-skill')];
          }
          return {
            'records': [_question('q-home')],
          };
        });
        final repository = PracticeRepository(
          api: api,
          stateStore: _Store(_loggedInSnapshot),
          now: () => DateTime(2026, 7, 16),
        );

        final home = await repository.load(
          const ModulePracticeRequest(module: _flatModule),
        );
        final related = await repository.load(
          const SkillPracticeRequest(skillId: 'skill-7'),
        );

        expect(home.access.fullAccess, isTrue);
        expect(related.access.fullAccess, isFalse);
      },
    );

    test(
      'module practice checks the selected post-purchase benefit kind',
      () async {
        for (final kind in PracticeBenefitKind.values) {
          final api = _Api((path, query) {
            if (path == '/app/user/getUserBenefits') {
              return [
                {
                  'benefitsCode': 'social-work:初级社工:社工实务:${kind.benefitType}',
                  'expireTime': '2026-12-31',
                },
              ];
            }
            return {
              'records': [_question('q-${kind.name}')],
            };
          });
          final repository = PracticeRepository(
            api: api,
            stateStore: _Store(_loggedInSnapshot),
            now: () => DateTime(2026, 7, 16),
          );

          final catalog = await repository.load(
            ModulePracticeRequest(module: _flatModule, benefitKind: kind),
          );

          expect(catalog.access.fullAccess, isTrue, reason: '$kind');
          expect(_questionIds(catalog), ['q-${kind.name}']);
        }
      },
    );

    test('keeps questions available when optional benefits fail', () async {
      final api = _Api((path, query) {
        if (path == '/app/user/getUserBenefits') {
          throw StateError('benefits offline');
        }
        return {
          'records': [_question('q-1')],
        };
      });
      final repository = PracticeRepository(
        api: api,
        stateStore: _Store(_loggedInSnapshot),
      );

      final catalog = await repository.load(
        const ModulePracticeRequest(module: _flatModule),
      );

      expect(_questionIds(catalog), ['q-1']);
      expect(catalog.access.fullAccess, isFalse);
    });
  });

  group('selected chapter practice loading', () {
    test('loads the selected descendant leaves and overlays records', () async {
      final api = _Api(
        (path, query) {
          if (path == '/app/shelf/getShelfTree') return _chapterTree;
          if (path == '/app/goods/listGoods') {
            return [_question('31'), _question('32')];
          }
          throw StateError('unexpected GET $path');
        },
        postResponder: (path, body) {
          expect(path, '/app/question/getQuestionRecordList');
          return const [
            {
              'shelfId': 31,
              'questionRecordResponseList': [
                {'questionId': 31, 'choose': 'B', 'isRight': 0},
              ],
            },
            {
              'shelfId': 32,
              'questionRecordResponseList': [
                {'questionId': 32, 'choose': 'A', 'isRight': 1},
              ],
            },
          ];
        },
      );
      final repository = PracticeRepository(
        api: api,
        stateStore: _Store({
          ..._loggedInSnapshot,
          'isLoggedIn': false,
          'chapterQuestionFreeCount': 2,
        }),
      );

      final catalog = await repository.load(
        const ChapterPracticeRequest(
          module: _chapterModule,
          catalogIndex: 1,
          chapterIndex: 1,
          entryMode: ChapterPracticeEntryMode.resume,
        ),
      );

      expect(api.getRequests.map((request) => request.path), [
        '/app/shelf/getShelfTree',
        '/app/goods/listGoods',
      ]);
      expect(api.getRequests.last.query, {
        'shelfIds': [31, 32],
      });
      expect(api.postRequests.first.body, {
        'modelId': 42,
        'shelfIdList': [11, 21, 31, 32, 41],
      });
      expect(_questionIds(catalog), ['31', '32']);
      expect(catalog.title, '第二章');
      expect(catalog.access.fullAccess, isTrue);
      expect(catalog.access.freeQuestionCount, 0);
      expect(
        (catalog.items[0] as PracticeQuestionItem).question.serverAnswer,
        const PracticeAnswer(choose: 'B', isRight: false),
      );
      expect(
        (catalog.items[1] as PracticeQuestionItem).question.serverAnswer,
        const PracticeAnswer(choose: 'A', isRight: true),
      );
      expect(catalog.chapterContext?.catalogIndex, 1);
      expect(catalog.chapterContext?.chapterIndex, 1);
      expect(catalog.chapterContext?.questionIds, ['31', '32']);
      expect(catalog.chapterContext?.nextChapter?.catalogIndex, 2);
      expect(catalog.chapterContext?.nextChapter?.chapterIndex, 0);
      expect(catalog.chapterContext?.nextChapter?.title, '第三组');
      expect(catalog.chapterContext?.nextChapter?.unlocked, isFalse);
    });

    test('pages one selected leaf with its module and shelf ids', () async {
      final api = _Api((path, query) {
        if (path == '/app/shelf/getShelfTree') return _chapterTree;
        if (path == '/app/goods/pageGoodsData') {
          return {
            'records': [_question('21')],
          };
        }
        throw StateError('unexpected GET $path');
      }, postResponder: (path, body) => const <Object?>[]);
      final repository = PracticeRepository(
        api: api,
        stateStore: _Store(const {
          'isLoggedIn': false,
          'chapterQuestionFreeCount': 2,
        }),
      );

      final catalog = await repository.load(
        const ChapterPracticeRequest(
          module: _chapterModule,
          catalogIndex: 1,
          chapterIndex: 0,
        ),
      );

      expect(api.getRequests.last.path, '/app/goods/pageGoodsData');
      expect(api.getRequests.last.query, {
        'pageNum': 1,
        'pageSize': 30,
        'modelId': 42,
        'shelfId': 21,
      });
      expect(_questionIds(catalog), ['21']);
      expect(catalog.chapterContext?.nextChapter?.chapterIndex, 1);
      expect(catalog.chapterContext?.nextChapter?.unlocked, isTrue);
    });

    test(
      'rejects invalid and locked chapter selections before goods I/O',
      () async {
        final api = _Api((path, query) {
          expect(path, '/app/shelf/getShelfTree');
          return _chapterTree;
        }, postResponder: (path, body) => const <Object?>[]);
        final repository = PracticeRepository(
          api: api,
          stateStore: _Store(const {
            'isLoggedIn': false,
            'chapterQuestionFreeCount': 2,
          }),
        );

        await expectLater(
          repository.load(
            const ChapterPracticeRequest(
              module: _chapterModule,
              catalogIndex: -1,
              chapterIndex: 0,
            ),
          ),
          throwsArgumentError,
        );
        expect(api.getRequests, isEmpty);

        await expectLater(
          repository.load(
            const ChapterPracticeRequest(
              module: _chapterModule,
              catalogIndex: 2,
              chapterIndex: 0,
            ),
          ),
          throwsStateError,
        );
        expect(
          api.getRequests.where(
            (request) => request.path.startsWith('/app/goods/'),
          ),
          isEmpty,
        );
      },
    );

    test(
      'redo clears only selected chapter records before returning',
      () async {
        var recordLoaded = false;
        final api = _Api(
          (path, query) {
            if (path == '/app/shelf/getShelfTree') {
              return const [
                {'id': 11, 'name': '重练章', 'goodsCount': 2},
              ];
            }
            if (path == '/app/goods/pageGoodsData') {
              return {
                'records': [_question('9007199254740993'), _question('43')],
              };
            }
            throw StateError('unexpected GET $path');
          },
          postResponder: (path, body) {
            if (path == '/app/question/getQuestionRecordList') {
              recordLoaded = true;
              return const [
                {
                  'shelfId': 11,
                  'questionRecordResponseList': [
                    {
                      'questionId': 9007199254740993,
                      'choose': 'A',
                      'isRight': 1,
                    },
                    {'questionId': 43, 'choose': 'B', 'isRight': 0},
                  ],
                },
              ];
            }
            expect(recordLoaded, isTrue);
            return null;
          },
        );
        final repository = PracticeRepository(
          api: api,
          stateStore: _Store(const {
            'isLoggedIn': false,
            'chapterQuestionFreeCount': 1,
            'selectedSubject': '社工实务',
            'selectedLevel': '初级社工',
          }),
        );

        final catalog = await repository.load(
          const ChapterPracticeRequest(
            module: _chapterModule,
            catalogIndex: 0,
            chapterIndex: 0,
            entryMode: ChapterPracticeEntryMode.redo,
          ),
        );

        expect(api.postRequests.map((request) => request.path), [
          '/app/question/getQuestionRecordList',
          '/app/question/deleteQuestionRecord',
        ]);
        expect(api.postRequests.last.body, {
          'questionIds': [9007199254740993, 43],
          'subject': '社工实务',
          'level': '初级社工',
          'type': 1,
        });
        expect(
          catalog.items.whereType<PracticeQuestionItem>().every(
            (item) => item.question.serverAnswer == null,
          ),
          isTrue,
        );
      },
    );

    test(
      'does not return a cleared redo session when deletion fails',
      () async {
        final api = _Api(
          (path, query) {
            if (path == '/app/shelf/getShelfTree') {
              return const [
                {'id': 11, 'name': '重练章', 'goodsCount': 1},
              ];
            }
            return {
              'records': [_question('43')],
            };
          },
          postResponder: (path, body) {
            if (path == '/app/question/getQuestionRecordList') {
              return const [
                {
                  'shelfId': 11,
                  'questionRecordResponseList': [
                    {'questionId': 43, 'choose': 'A', 'isRight': 1},
                  ],
                },
              ];
            }
            throw StateError('delete offline');
          },
        );
        final repository = PracticeRepository(
          api: api,
          stateStore: _Store(const {
            'isLoggedIn': false,
            'chapterQuestionFreeCount': 1,
            'selectedSubject': '社工实务',
            'selectedLevel': '初级社工',
          }),
        );

        await expectLater(
          repository.load(
            const ChapterPracticeRequest(
              module: _chapterModule,
              catalogIndex: 0,
              chapterIndex: 0,
              entryMode: ChapterPracticeEntryMode.redo,
            ),
          ),
          throwsStateError,
        );
        expect(
          api.postRequests.last.path,
          '/app/question/deleteQuestionRecord',
        );
      },
    );
  });

  group('Mine review loading', () {
    test('loads every error page using total as the paging fallback', () async {
      final api = _Api((path, query) {
        expect(path, '/app/question/pageErrorQuestion');
        return {
          'total': 201,
          'pages': 1,
          'current': query['pageNum'],
          'size': 200,
          'records': [_question('error-${query['pageNum']}')],
        };
      });
      final repository = PracticeRepository(
        api: api,
        stateStore: _Store(_loggedInSnapshot),
      );

      final catalog = await repository.load(const ErrorPracticeRequest());

      expect(api.getRequests.map((request) => request.path), [
        '/app/question/pageErrorQuestion',
        '/app/question/pageErrorQuestion',
      ]);
      expect(api.getRequests.map((request) => request.query), [
        {'pageNum': 1, 'pageSize': 200, 'subject': '社工实务', 'level': '初级社工'},
        {'pageNum': 2, 'pageSize': 200, 'subject': '社工实务', 'level': '初级社工'},
      ]);
      expect(_questionIds(catalog), ['error-1', 'error-2']);
      expect(catalog.title, '我的错题');
      expect(catalog.access.fullAccess, isTrue);
      expect(catalog.behavior.restoreServerAnswers, isFalse);
      expect(catalog.behavior.persistAnswers, isFalse);
      expect(catalog.behavior.showResults, isFalse);
      expect(catalog.behavior.emptyMessage, '还没有错题哟');
    });

    test('loads all declared collection pages without benefits', () async {
      final api = _Api((path, query) {
        expect(path, '/app/question/pageCollectQuestion');
        return {
          'total': 2,
          'pages': 2,
          'current': query['pageNum'],
          'size': 200,
          'records': [
            {
              ..._question('collect-${query['pageNum']}'),
              'choose': 'B',
              'isRight': false,
            },
          ],
        };
      });
      final repository = PracticeRepository(
        api: api,
        stateStore: _Store(_loggedInSnapshot),
      );

      final catalog = await repository.load(const CollectionPracticeRequest());

      expect(api.getRequests, hasLength(2));
      expect(
        api.getRequests.every(
          (request) => request.path == '/app/question/pageCollectQuestion',
        ),
        isTrue,
      );
      expect(_questionIds(catalog), ['collect-1', 'collect-2']);
      expect(catalog.title, '我的收藏');
      expect(catalog.access.fullAccess, isTrue);
      expect(catalog.behavior.emptyMessage, '暂无收藏题目');
      expect(
        (catalog.items.first as PracticeQuestionItem).question.serverAnswer,
        isNotNull,
      );
      expect(
        api.getRequests.where(
          (request) => request.path == '/app/user/getUserBenefits',
        ),
        isEmpty,
      );
    });
  });

  group('validation and records', () {
    test('rejects invalid entry requests before network I/O', () async {
      final api = _Api((path, query) => throw StateError('unexpected I/O'));
      final repository = PracticeRepository(
        api: api,
        stateStore: _Store(const {}),
      );

      await expectLater(
        repository.load(
          const ModulePracticeRequest(
            module: HomeModule(id: 0, name: '练题', page: '技巧练题', tag: ''),
          ),
        ),
        throwsArgumentError,
      );
      await expectLater(
        repository.load(const SkillPracticeRequest(skillId: '  ')),
        throwsArgumentError,
      );
      expect(api.getRequests, isEmpty);
    });

    test('posts the exact Android question-record payload', () async {
      final api = _Api((path, query) => null);
      final repository = PracticeRepository(
        api: api,
        stateStore: _Store(const {}),
      );
      final question = PracticeQuestion.fromMap({
        ..._question('9007199254740993'),
        'subject': '社工实务',
        'level': '初级社工',
      });

      await repository.saveAnswer(
        question,
        const PracticeAnswer(choose: 'AC', isRight: true),
      );

      expect(api.postRequests.single.path, '/app/question/saveQuestionRecord');
      expect(api.postRequests.single.body, {
        'questionId': 9007199254740993,
        'subject': '社工实务',
        'level': '初级社工',
        'choose': 'AC',
        'isRight': 1,
      });
    });

    test('rejects a non-numeric record id before posting', () async {
      final api = _Api((path, query) => null);
      final repository = PracticeRepository(
        api: api,
        stateStore: _Store(const {}),
      );

      await expectLater(
        repository.saveAnswer(
          PracticeQuestion.fromMap(_question('not-numeric')),
          const PracticeAnswer(choose: 'A', isRight: false),
        ),
        throwsArgumentError,
      );
      expect(api.postRequests, isEmpty);
    });
  });

  group('review management commands', () {
    test('loads the current question skills from the Android endpoint', () async {
      final api = _Api((path, query) {
        expect(path, '/knowledge/skill/querySkillsByQuestion');
        return [
          {
            'skillId': 'skill-42',
            'text': '看到关键词就选 A',
            'keyword': '关键词',
            'note': '这是技巧解析',
          },
        ];
      });
      final repository = PracticeRepository(
        api: api,
        stateStore: _Store(const {}),
      );

      final skills = await repository.loadSkillsForQuestion('42');

      expect(api.getRequests.single.query, {'questionId': 42});
      expect(skills.single.skillId, 'skill-42');
      expect(skills.single.displayText, '看到关键词就选 A');
      expect(skills.single.note, '这是技巧解析');
    });

    test(
      'posts exact collect and uncollect payloads from current selection',
      () async {
        final api = _Api((path, query) => null);
        final repository = PracticeRepository(
          api: api,
          stateStore: _Store(_loggedInSnapshot),
        );
        final question = PracticeQuestion.fromMap({
          ..._question('9007199254740993'),
          'subject': 'stale subject',
          'level': 'stale level',
        });

        await repository.setCollected(question, true);
        await repository.setCollected(question, false);

        expect(api.postRequests.map((request) => request.path), [
          '/app/question/saveCollectQuestion',
          '/app/question/deleteCollectQuestion',
        ]);
        expect(api.postRequests.first.body, {
          'questionId': 9007199254740993,
          'subject': '社工实务',
          'level': '初级社工',
        });
        expect(api.postRequests.last.body, {
          'questionIds': [9007199254740993],
          'subject': '社工实务',
          'level': '初级社工',
        });
      },
    );

    test('posts exact manual wrong-question removal payload', () async {
      final api = _Api((path, query) => null);
      final repository = PracticeRepository(
        api: api,
        stateStore: _Store(_loggedInSnapshot),
      );

      await repository.removeWrongQuestion(
        PracticeQuestion.fromMap(_question('42')),
      );

      expect(
        api.postRequests.single.path,
        '/app/question/deleteQuestionRecord',
      );
      expect(api.postRequests.single.body, {
        'questionIds': [42],
        'subject': '社工实务',
        'level': '初级社工',
        'type': 2,
      });
    });

    test('clears all current-subject practice records like Android', () async {
      final api = _Api((path, query) => null);
      final repository = PracticeRepository(
        api: api,
        stateStore: _Store(_loggedInSnapshot),
      );

      await repository.clearPracticeRecords();

      expect(
        api.postRequests.single.path,
        '/app/question/deleteQuestionRecord',
      );
      expect(api.postRequests.single.body, {
        'questionIds': const <int>[],
        'subject': '社工实务',
        'level': '初级社工',
        'type': 1,
      });
    });

    test(
      'submits the Android-compatible question correction payload',
      () async {
        final api = _Api((path, query) => null);
        final repository = PracticeRepository(
          api: api,
          stateStore: _Store({
            ..._loggedInSnapshot,
            'userId': '2038529229062426626',
            'phone': '13800138000',
          }),
        );
        final question = PracticeQuestion.fromMap(_question('42'));

        await repository.submitCorrection(
          question: question,
          serialNumber: 3,
          type: 2,
          content: '  答案应为 B  ',
        );

        expect(
          api.postRequests.single.path,
          '/app/questionCorrect/createCorrectItem',
        );
        expect(api.postRequests.single.body, {
          'carType': 1,
          'course': 1,
          'type': 2,
          'questionId': '42',
          'content': '答案应为 B',
          'userId': '2038529229062426626',
          'serialNumber': 3,
          'images': const <String>[],
          'mobile': '13800138000',
        });
      },
    );

    test(
      'probes login and the exact Home error-question count request',
      () async {
        final loggedOutApi = _Api((path, query) => throw StateError('no I/O'));
        final loggedOut = PracticeRepository(
          api: loggedOutApi,
          stateStore: _Store(const {'isLoggedIn': false}),
        );

        final loggedOutAvailability = await loggedOut.probeErrorPractice();

        expect(loggedOutAvailability.requiresLogin, isTrue);
        expect(loggedOutApi.getRequests, isEmpty);

        final api = _Api((path, query) {
          expect(path, '/app/question/pageErrorQuestion');
          return {'total': '2'};
        });
        final repository = PracticeRepository(
          api: api,
          stateStore: _Store(_loggedInSnapshot),
        );

        final availability = await repository.probeErrorPractice();

        expect(availability.requiresLogin, isFalse);
        expect(availability.total, 2);
        expect(api.getRequests.single.query, {
          'pageNum': 1,
          'pageSize': 1,
          'subject': '社工实务',
          'level': '初级社工',
        });
      },
    );

    test('delegates threshold persistence using the legacy count id', () async {
      final reviewStore = _ReviewStore(threshold: 3, thresholdReached: true);
      final repository = PracticeRepository(
        api: _Api((path, query) => null),
        stateStore: _Store(_loggedInSnapshot),
        reviewStore: reviewStore,
      );
      final question = PracticeQuestion.fromMap({
        ..._question('9007199254740993'),
        'id': 314,
      });

      expect(await repository.loadWrongRemovalThreshold(), 3);
      await repository.saveWrongRemovalThreshold(7);
      expect(await repository.recordWrongQuestionCorrect(question), isTrue);

      expect(reviewStore.savedThresholds, [7]);
      expect(reviewStore.recordedQuestionIds, ['314']);
      await expectLater(
        repository.saveWrongRemovalThreshold(0),
        throwsArgumentError,
      );
    });
  });
}

const _flatModule = HomeModule(
  id: 42,
  name: '技巧练题',
  page: '技巧练题',
  tag: 'hot',
  type: '扁平化',
);

const _structuredModule = HomeModule(
  id: 42,
  name: '技巧练题',
  page: '技巧练题',
  tag: '',
  type: '结构化',
);

const _chapterModule = HomeModule(
  id: 42,
  name: '章节练习',
  page: '章节练习',
  tag: '',
  type: '结构化',
);

const _fastModule = HomeModule(id: 42, name: '速成300题', page: '速成300题', tag: '');

const _fastRequest = FastPracticeRequest(
  module: _fastModule,
  shelfId: 111,
  shelfName: '精选一',
  shelfType: '扁平化',
);

const _dailyModule = HomeModule(id: 42, name: '每日一招', page: '每日一招', tag: '');

const _dailyRequest = DailySkillPracticeRequest(
  module: _dailyModule,
  skillId: '11',
  shelfId: 111,
);

const _chapterTree = <Object?>[
  {'id': 11, 'name': '第一组', 'goodsCount': 1},
  {
    'id': 20,
    'name': '第二组',
    'children': [
      {'id': 21, 'name': '第一章', 'goodsCount': 1},
      {
        'id': 30,
        'name': '第二章',
        'goodsCount': 2,
        'children': [
          {'id': 31, 'name': '叶一'},
          {'id': 32, 'name': '叶二'},
        ],
      },
    ],
  },
  {'id': 41, 'name': '第三组', 'goodsCount': 1},
];

const _singleLeafTree = [
  {
    'id': 100,
    'name': '目录一',
    'children': [
      {
        'id': 110,
        'name': '章节一',
        'children': [
          {'id': 111, 'name': '叶一'},
        ],
      },
      {'id': 120, 'name': '章节二'},
    ],
  },
  {'id': 200, 'name': '目录二'},
];

const _multiLeafTree = [
  {
    'id': 100,
    'name': '目录一',
    'children': [
      {
        'id': 110,
        'name': '章节一',
        'children': [
          {'id': 111, 'name': '叶一'},
          {'id': 112, 'name': '叶二'},
        ],
      },
    ],
  },
];

const _loggedInSnapshot = <String, dynamic>{
  'isLoggedIn': true,
  'category': 'social-work',
  'selectedLevel': '初级社工',
  'selectedSubject': '社工实务',
  'skillQuestionFreeCount': 5,
};

Map<String, dynamic> _question(String id) => {
  'questionId': id,
  'title': '题目 $id',
  'questionType': '单选题',
  'options': {'A': '正确', 'B': '错误'},
  'answer': 'A',
};

List<String> _questionIds(PracticeCatalog catalog) {
  return catalog.items
      .whereType<PracticeQuestionItem>()
      .map((item) => item.question.id)
      .toList(growable: false);
}

final class _Request {
  const _Request({required this.path, required this.query, required this.body});

  final String path;
  final Map<String, dynamic> query;
  final Map<String, dynamic>? body;
}

typedef _GetResponder =
    Object? Function(String path, Map<String, dynamic> query);
typedef _PostResponder =
    Object? Function(String path, Map<String, dynamic> body);

final class _Api implements AppApiClient {
  _Api(this._getResponder, {this.postResponder});

  final _GetResponder _getResponder;
  final _PostResponder? postResponder;
  final List<_Request> getRequests = [];
  final List<_Request> postRequests = [];

  @override
  Future<Object?> getBody(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final query = queryParameters ?? const <String, dynamic>{};
    getRequests.add(_Request(path: path, query: query, body: null));
    return _getResponder(path, query);
  }

  @override
  Future<Object?> postBody(String path, Map<String, dynamic> body) async {
    postRequests.add(_Request(path: path, query: const {}, body: body));
    return postResponder?.call(path, body);
  }
}

final class _Store implements LegacyAppStateStore {
  _Store(this.snapshot);

  final Map<String, dynamic> snapshot;

  @override
  Future<Map<String, dynamic>> readAppSnapshot() async => snapshot;

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

final class _ThrowingStore implements LegacyAppStateStore {
  @override
  Future<Map<String, dynamic>> readAppSnapshot() async {
    throw StateError('unexpected state read');
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

final class _ReviewStore implements PracticeReviewStore {
  _ReviewStore({required this.threshold, required this.thresholdReached});

  final int threshold;
  final bool thresholdReached;
  final List<int> savedThresholds = [];
  final List<String> recordedQuestionIds = [];

  @override
  Future<int> loadWrongRemovalThreshold() async => threshold;

  @override
  Future<void> saveWrongRemovalThreshold(int value) async {
    savedThresholds.add(value);
  }

  @override
  Future<bool> recordWrongQuestionCorrect(String questionId) async {
    recordedQuestionIds.add(questionId);
    return thresholdReached;
  }
}
