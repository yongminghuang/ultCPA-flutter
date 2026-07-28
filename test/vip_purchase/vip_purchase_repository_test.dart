import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/network/app_api_client.dart';
import 'package:ultcpa_flutter/src/storage/legacy_app_state_store.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_purchase_models.dart';
import 'package:ultcpa_flutter/src/vip_purchase/vip_purchase_repository.dart';

void main() {
  group('VIP purchase session', () {
    test(
      'loads expanded types selected subject benefits and Mine source',
      () async {
        final api = _Api((request) {
          return switch (request.path) {
            '/app/tempMedia/countGroupByLevelAndSubject' => [
              {'level': '中级会计', 'subject': '财务管理', 'count': '3'},
            ],
            '/app/user/getUserBenefits' => [
              {
                'category': 'joy-ledger',
                'benefitsCode': 'KJ_PRACTICE_REGULAR_L2_3M',
                'expireTime': '2026-07-19',
              },
            ],
            _ => throw StateError('unexpected ${request.path}'),
          };
        });
        final repository = VipPurchaseRepository(
          api: api,
          stateStore: _StateStore(
            _snapshot(
              isLoggedIn: true,
              selectedMarketId: 8,
              selectedSubject: '财务管理',
              defaultPayType: 2,
            ),
          ),
          now: () => DateTime(2026, 7, 17, 12),
        );

        final session = await repository.loadSession(
          const VipPurchaseRequest.mine(),
        );

        expect(session.category, 'joy-ledger');
        expect(session.level, '中级会计');
        expect(session.subjects, const [
          VipSubject(id: 6, name: '会计实务'),
          VipSubject(id: 7, name: '经济法'),
          VipSubject(id: 8, name: '财务管理'),
        ]);
        expect(session.initialSubjectIndex, 2);
        expect(session.productTypes, [
          VipProductType.svip,
          VipProductType.skill,
          VipProductType.course,
        ]);
        expect(session.initialProductType, VipProductType.svip);
        expect(session.isLoggedIn, isTrue);
        expect(session.showWechatPay, isTrue);
        expect(session.initialPaymentChannel, VipPaymentChannel.alipay);
        expect(session.payPageSourceId, 2002);
        expect(session.nickname, '迁移用户');
        expect(session.avatarUrl, 'https://example.com/avatar.png');
        expect(session.benefitLines, isEmpty);
        expect(api.requests.map((request) => request.path), [
          '/app/tempMedia/countGroupByLevelAndSubject',
          '/app/user/getUserBenefits',
        ]);
        expect(
          api.requests.every((request) => request.method == 'GET'),
          isTrue,
        );
      },
    );

    test(
      'keeps skill only and skips benefits for a logged-out session',
      () async {
        final api = _Api((request) {
          expect(request.path, '/app/tempMedia/countGroupByLevelAndSubject');
          return [
            {'level': '中级会计', 'subject': '会计实务', 'count': 0},
            {'level': '初级会计', 'subject': '经济法', 'count': 5},
          ];
        });
        final repository = VipPurchaseRepository(
          api: api,
          stateStore: _StateStore(
            _snapshot(
              isLoggedIn: false,
              selectedMarketId: 999,
              selectedSubject: '',
              showWxPay: false,
              defaultPayType: 1,
            ),
          ),
        );

        final session = await repository.loadSession(
          const VipPurchaseRequest.mine(
            defaultProductType: VipProductType.course,
          ),
        );

        expect(session.initialSubjectIndex, 0);
        expect(session.productTypes, [VipProductType.skill]);
        expect(session.initialProductType, VipProductType.skill);
        expect(session.isLoggedIn, isFalse);
        expect(session.showWechatPay, isFalse);
        expect(session.initialPaymentChannel, VipPaymentChannel.alipay);
        expect(session.payPageSourceId, 1020);
        expect(api.requests, hasLength(1));
      },
    );

    test('uses cached benefits when optional live dependencies fail', () async {
      final api = _Api(
        (request) => throw StateError('${request.path} offline'),
      );
      final repository = VipPurchaseRepository(
        api: api,
        stateStore: _StateStore(
          _snapshot(
            isLoggedIn: true,
            selectedMarketId: 6,
            selectedSubject: '会计实务',
            userBenefitsJson: jsonEncode([
              {
                'category': 'joy-ledger',
                'benefitsCode': 'KJ_MEMBER_L2_3M',
                'expireTime': '2026-07-19',
              },
            ]),
          ),
        ),
        now: () => DateTime(2026, 7, 17, 12),
      );

      final session = await repository.loadSession(
        const VipPurchaseRequest.mine(),
      );

      expect(session.productTypes, [VipProductType.skill]);
      expect(session.benefitLines.map((line) => line.text), [
        '中级会计 全能SVIP 有效期至 2026-07-19',
      ]);
      expect(session.payPageSourceId, 1020);
      expect(api.requests, hasLength(2));
    });

    test(
      'recovers subjects from category body then Android fallback',
      () async {
        final api = _Api((_) => const <Object>[]);
        final fromBody = VipPurchaseRepository(
          api: api,
          stateStore: _StateStore(
            _snapshot(
              selectedCategoryJson: '{bad json',
              categoryBodyJson: jsonEncode({
                'joy-ledger': [
                  {
                    'id': 202,
                    'level': '中级会计',
                    'name': '中级会计',
                    'children': [
                      {'id': 31, 'name': '中级会计实务'},
                      {'id': 32, 'name': '中级经济法'},
                    ],
                  },
                ],
              }),
              selectedMarketId: 32,
              selectedSubject: '中级经济法',
            ),
          ),
        );
        final fallback = VipPurchaseRepository(
          api: api,
          stateStore: _StateStore(
            _snapshot(
              selectedCategoryJson: '{}',
              categoryBodyJson: '{bad json',
              selectedMarketId: -1,
              selectedSubject: '',
            ),
          ),
        );

        final fromBodySession = await fromBody.loadSession(
          const VipPurchaseRequest.mine(),
        );
        final fallbackSession = await fallback.loadSession(
          const VipPurchaseRequest.mine(),
        );

        expect(fromBodySession.subjects, const [
          VipSubject(id: 31, name: '中级会计实务'),
          VipSubject(id: 32, name: '中级经济法'),
        ]);
        expect(fromBodySession.initialSubjectIndex, 1);
        expect(fallbackSession.subjects, const [
          VipSubject(id: 6, name: '会计实务'),
          VipSubject(id: 7, name: '经济法基础'),
        ]);
        expect(fallbackSession.initialSubjectIndex, 0);
      },
    );

    test(
      'non-list optional bodies degrade without failing the session',
      () async {
        for (final value in <Object?>[null, const {}, 'bad']) {
          final repository = VipPurchaseRepository(
            api: _Api((_) => value),
            stateStore: _StateStore(
              _snapshot(
                isLoggedIn: true,
                selectedMarketId: 6,
                selectedSubject: '会计实务',
              ),
            ),
          );

          final session = await repository.loadSession(
            const VipPurchaseRequest.mine(),
          );

          expect(session.productTypes, [
            VipProductType.skill,
          ], reason: '$value');
          expect(session.benefitLines, isEmpty, reason: '$value');
          expect(session.payPageSourceId, 1020, reason: '$value');
        }
      },
    );
  });

  group('VIP product and common SKU loading', () {
    test('queries selected subjects sequentially then common SKUs', () async {
      var activeProductRequests = 0;
      var maxActiveProductRequests = 0;
      final api = _Api((request) async {
        if (request.path == '/app/product/v1/queryProduct') {
          activeProductRequests += 1;
          if (activeProductRequests > maxActiveProductRequests) {
            maxActiveProductRequests = activeProductRequests;
          }
          await Future<void>.delayed(Duration.zero);
          activeProductRequests -= 1;
          final subject = request.body!['subject'];
          if (subject == '经济法') {
            return [
              {
                'productId': 'product-7',
                'subject': '经济法',
                'skuList': [
                  {
                    'skuProductId': 702,
                    'skuName': '季卡',
                    'benefitsExpiryMinute': 129600,
                  },
                ],
              },
            ];
          }
          return {
            'productId': 'product-6',
            'subject': '会计实务',
            'skuList': [
              {
                'skuProductId': 602,
                'skuName': '季卡',
                'benefitsExpiryMinute': 129600,
              },
            ],
          };
        }
        expect(request.path, '/app/product/v1/queryCommonProductSku');
        return [
          {
            'skuName': '季卡',
            'totalPrice': 39.9,
            'aggProductList': [
              {'productId': 'product-7', 'productSkuId': 702},
              {'productId': 'product-6', 'productSkuId': 602},
            ],
          },
        ];
      });
      final repository = VipPurchaseRepository(
        api: api,
        stateStore: _StateStore(const {}),
      );

      final selection = await repository.loadSkus(
        session: _session(),
        type: VipProductType.skill,
        subjects: const [
          VipSubject(id: 7, name: '经济法'),
          VipSubject(id: 6, name: '会计实务'),
        ],
      );

      expect(maxActiveProductRequests, 1);
      expect(api.requests.map((request) => request.path), [
        '/app/product/v1/queryProduct',
        '/app/product/v1/queryProduct',
        '/app/product/v1/queryCommonProductSku',
      ]);
      expect(api.requests[0].body, {
        'category': 'joy-ledger',
        'level': '中级会计',
        'subject': '经济法',
        'productType': 'skills_feature_package',
        'productId': null,
        'loadSameTypeProducts': true,
      });
      expect(api.requests[1].body, {
        'category': 'joy-ledger',
        'level': '中级会计',
        'subject': '会计实务',
        'productType': 'skills_feature_package',
        'productId': null,
        'loadSameTypeProducts': true,
      });
      expect(api.requests[2].body, {
        'productIds': ['product-7', 'product-6'],
      });
      expect(selection.products.map((product) => product.productId), [
        'product-7',
        'product-6',
      ]);
      expect(selection.skus.single.skuName, '季卡');
      expect(selection.skus.single.shopCart, const [
        VipShopCartItem(productId: 'product-7', productSkuId: 702),
        VipShopCartItem(productId: 'product-6', productSkuId: 602),
      ]);
      expect(resolveVipSkuDays('季卡', selection.products.first.skus), 90);
    });

    test('skips common SKU request when no valid product survives', () async {
      final api = _Api((request) {
        return request.body!['subject'] == '经济法'
            ? {'productId': '', 'skuList': const []}
            : null;
      });
      final repository = VipPurchaseRepository(
        api: api,
        stateStore: _StateStore(const {}),
      );

      final selection = await repository.loadSkus(
        session: _session(),
        type: VipProductType.course,
        subjects: const [
          VipSubject(id: 7, name: '经济法'),
          VipSubject(id: 6, name: '会计实务'),
        ],
      );

      expect(selection.products, isEmpty);
      expect(selection.skus, isEmpty);
      expect(api.requests, hasLength(2));
      expect(
        api.requests.every(
          (request) => request.path == '/app/product/v1/queryProduct',
        ),
        isTrue,
      );
      expect(api.requests.first.body!['productType'], 'video_course');
    });

    test('uses the first valid product from an array body', () async {
      final api = _Api((request) {
        if (request.path == '/app/product/v1/queryProduct') {
          return [
            {'productId': ''},
            {'productId': 'product-second', 'skuList': const []},
            {'productId': 'product-third', 'skuList': const []},
          ];
        }
        return [
          {
            'skuName': '月卡',
            'totalPrice': 19.9,
            'aggProductList': [
              {'productId': 'product-second', 'productSkuId': 11},
            ],
          },
        ];
      });
      final repository = VipPurchaseRepository(
        api: api,
        stateStore: _StateStore(const {}),
      );

      final selection = await repository.loadSkus(
        session: _session(),
        type: VipProductType.svip,
        subjects: const [VipSubject(id: 6, name: '会计实务')],
      );

      expect(selection.products.single.productId, 'product-second');
      expect(api.requests.last.body, {
        'productIds': ['product-second'],
      });
    });

    test('rejects malformed common SKU body and entries', () async {
      for (final commonBody in <Object?>[
        const {},
        [
          {
            'skuName': '季卡',
            'totalPrice': 39.9,
            'aggProductList': [
              {'productId': 'p', 'productSkuId': 0},
            ],
          },
        ],
      ]) {
        final api = _Api((request) {
          if (request.path == '/app/product/v1/queryProduct') {
            return {'productId': 'p', 'skuList': const []};
          }
          return commonBody;
        });
        final repository = VipPurchaseRepository(
          api: api,
          stateStore: _StateStore(const {}),
        );

        expect(
          repository.loadSkus(
            session: _session(),
            type: VipProductType.skill,
            subjects: const [VipSubject(id: 6, name: '会计实务')],
          ),
          throwsFormatException,
          reason: '$commonBody',
        );
      }
    });
  });

  group('VIP purchase success summary', () {
    test(
      'refreshes benefits once and resolves the current session member tier',
      () async {
        final api = _Api((request) {
          expect(request.method, 'GET');
          expect(request.path, '/app/user/getUserBenefits');
          expect(request.queryParameters, isNull);
          expect(request.body, isNull);
          return [
            {
              'category': 'other-category',
              'benefitsCode': 'joy-ledger:中级会计:会计实务:all',
              'benefitsDesc': '错误会员',
              'expireTime': '2026-08-01',
            },
            {
              'category': 'joy-ledger',
              'benefitsCode': 'joy-ledger:中级会计:会计实务:all',
              'benefitsDesc': ' 中级会计畅学卡 ',
              'expireTime': '2026-08-01',
            },
            {
              'category': 'joy-ledger',
              'benefitsCode': 'joy-ledger:中级会计:经济法:all',
              'benefitsDesc': '后一个会员',
              'expireTime': '2026-09-01',
            },
          ];
        });
        final repository = VipPurchaseRepository(
          api: api,
          stateStore: _StateStore(const {}),
          now: () => DateTime(2026, 7, 17, 12),
        );

        final summary = await repository.loadSuccessSummary(_session());

        expect(
          summary,
          const VipPurchaseSuccessSummary(
            title: '恭喜！【中级会计畅学卡】开通成功',
            expiresOn: '2026-08-01',
            hasMemberTier: true,
          ),
        );
        expect(api.requests, hasLength(1));
      },
    );

    test('degrades request failures and malformed bodies to generic', () async {
      final cases = <FutureOr<Object?> Function(_ApiRequest)>[
        (_) => throw const AppApiException('offline'),
        (_) => null,
        (_) => const <String, Object?>{},
        (_) => 'not a list',
        (_) => const [42, 'bad', null],
        (_) => const [
          {
            'category': 'joy-ledger',
            'benefitsCode': 'joy-ledger:中级会计:会计实务:course',
            'benefitsDesc': '课程包',
            'expireTime': '2026-08-01',
          },
        ],
      ];

      for (final handler in cases) {
        final api = _Api(handler);
        final repository = VipPurchaseRepository(
          api: api,
          stateStore: _StateStore(const {}),
          now: () => DateTime(2026, 7, 17, 12),
        );

        expect(
          await repository.loadSuccessSummary(_session()),
          const VipPurchaseSuccessSummary.generic(),
        );
        expect(api.requests, hasLength(1));
        expect(api.requests.single.method, 'GET');
        expect(api.requests.single.path, '/app/user/getUserBenefits');
        expect(api.requests.single.queryParameters, isNull);
        expect(api.requests.single.body, isNull);
      }
    });
  });

  group('VIP order creation and WeChat confirmation', () {
    const shopCart = [
      VipShopCartItem(productId: 'product-7', productSkuId: 702),
      VipShopCartItem(productId: 'product-6', productSkuId: 602),
    ];

    test(
      'creates exact WeChat order and parses all credential fields',
      () async {
        final api = _Api((request) {
          expect(request.path, '/app/order/v1/wxPayOrder');
          return {
            'orderId': 'order-wx',
            'credential': {
              'appId': 'wx-app',
              'partnerId': 'partner',
              'prepayId': 'prepay',
              'nonceStr': 'nonce',
              'timeStamp': '123456',
              'packageValue': 'Sign=WXPay',
              'sign': 'signature',
            },
          };
        });
        final repository = VipPurchaseRepository(
          api: api,
          stateStore: _StateStore(const {}),
        );

        final order = await repository.createOrder(
          session: _session(payPageSourceId: 2002),
          channel: VipPaymentChannel.wechat,
          shopCart: shopCart,
        );

        expect(api.requests.single.method, 'POST');
        expect(api.requests.single.body, {
          'commodityId': null,
          'payPageSourceId': 2002,
          'shopCart': [
            {'productId': 'product-7', 'productSkuId': 702},
            {'productId': 'product-6', 'productSkuId': 602},
          ],
        });
        expect(order.orderId, 'order-wx');
        expect(order.wechatCredential!.toMap(), {
          'appId': 'wx-app',
          'partnerId': 'partner',
          'prepayId': 'prepay',
          'nonceStr': 'nonce',
          'timeStamp': '123456',
          'packageValue': 'Sign=WXPay',
          'sign': 'signature',
        });
        expect(order.alipayOrderInfo, isNull);
      },
    );

    test(
      'creates exact Alipay order and normalizes quoted credential',
      () async {
        final api = _Api((request) {
          expect(request.path, '/app/order/v1/aliPayOrder');
          return {
            'orderId': 'order-ali',
            'credential': r'"partner="2088"&biz_content="value""',
          };
        });
        final repository = VipPurchaseRepository(
          api: api,
          stateStore: _StateStore(const {}),
        );

        final order = await repository.createOrder(
          session: _session(),
          channel: VipPaymentChannel.alipay,
          shopCart: shopCart,
        );

        expect(api.requests.single.body!['payPageSourceId'], 1020);
        expect(order.orderId, 'order-ali');
        expect(order.wechatCredential, isNull);
        expect(order.alipayOrderInfo, 'partner="2088"&biz_content="value"');
      },
    );

    test('rejects empty carts and malformed order responses', () async {
      final noCallApi = _Api((_) => throw StateError('must not call'));
      final noCallRepository = VipPurchaseRepository(
        api: noCallApi,
        stateStore: _StateStore(const {}),
      );

      expect(
        noCallRepository.createOrder(
          session: _session(),
          channel: VipPaymentChannel.wechat,
          shopCart: const [],
        ),
        throwsArgumentError,
      );
      expect(noCallApi.requests, isEmpty);

      for (final body in <Object?>[
        null,
        const {'orderId': ''},
        const {'orderId': 'order', 'credential': {}},
      ]) {
        final repository = VipPurchaseRepository(
          api: _Api((_) => body),
          stateStore: _StateStore(const {}),
        );
        expect(
          repository.createOrder(
            session: _session(),
            channel: VipPaymentChannel.wechat,
            shopCart: shopCart,
          ),
          throwsFormatException,
          reason: '$body',
        );
      }
    });

    test('confirms only the exact successful WeChat status body', () async {
      for (final entry in <(Object?, bool)>[
        ('成功', true),
        (' 成功 ', false),
        ('待支付', false),
        ('取消', false),
        (null, false),
        ({'status': '成功'}, false),
      ]) {
        final api = _Api((request) {
          expect(request.method, 'GET');
          expect(request.path, '/app/order/v2/getOrderPayStatus');
          return entry.$1;
        });
        final repository = VipPurchaseRepository(
          api: api,
          stateStore: _StateStore(const {}),
        );

        expect(
          await repository.confirmWechatPayment(),
          entry.$2,
          reason: '${entry.$1}',
        );
        expect(api.requests.single.body, isNull);
      }
    });
  });
}

VipPurchaseSession _session({int payPageSourceId = 1020}) {
  return VipPurchaseSession(
    request: const VipPurchaseRequest.mine(),
    category: 'joy-ledger',
    level: '中级会计',
    subjects: const [
      VipSubject(id: 6, name: '会计实务'),
      VipSubject(id: 7, name: '经济法'),
    ],
    initialSubjectIndex: 0,
    productTypes: const [VipProductType.skill],
    initialProductType: VipProductType.skill,
    isLoggedIn: true,
    showWechatPay: true,
    initialPaymentChannel: VipPaymentChannel.wechat,
    payPageSourceId: payPageSourceId,
    nickname: '迁移用户',
    avatarUrl: '',
    benefitLines: const [],
  );
}

Map<String, dynamic> _snapshot({
  bool isLoggedIn = false,
  int selectedMarketId = 6,
  String selectedSubject = '会计实务',
  bool showWxPay = true,
  int defaultPayType = 1,
  String userBenefitsJson = '',
  String? selectedCategoryJson,
  String? categoryBodyJson,
}) {
  final selectedCategory = {
    'id': 202,
    'level': '中级会计',
    'name': '中级会计',
    'children': [
      {'id': 6, 'name': '会计实务'},
      {'id': 7, 'name': '经济法'},
      {'id': 8, 'name': '财务管理'},
    ],
  };
  return {
    'category': 'joy-ledger',
    'selectedCategoryJson':
        selectedCategoryJson ?? jsonEncode(selectedCategory),
    'selectedCategoryKey': 'joy-ledger_202',
    'selectedLevel': '中级会计',
    'selectedMarketId': selectedMarketId,
    'selectedSubject': selectedSubject,
    'categoryBodyJson':
        categoryBodyJson ??
        jsonEncode({
          'joy-ledger': [selectedCategory],
        }),
    'isLoggedIn': isLoggedIn,
    'nickname': '迁移用户',
    'avatar': 'https://example.com/avatar.png',
    'showWxPay': showWxPay,
    'defaultPayType': defaultPayType,
    'userBenefitsJson': userBenefitsJson,
  };
}

final class _ApiRequest {
  const _ApiRequest({
    required this.method,
    required this.path,
    this.queryParameters,
    this.body,
  });

  final String method;
  final String path;
  final Map<String, dynamic>? queryParameters;
  final Map<String, dynamic>? body;
}

final class _Api implements AppApiClient {
  _Api(this.handler);

  final FutureOr<Object?> Function(_ApiRequest request) handler;
  final requests = <_ApiRequest>[];

  @override
  Future<Object?> getBody(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final request = _ApiRequest(
      method: 'GET',
      path: path,
      queryParameters: queryParameters,
    );
    requests.add(request);
    return await handler(request);
  }

  @override
  Future<Object?> postBody(String path, Map<String, dynamic> body) async {
    final request = _ApiRequest(method: 'POST', path: path, body: body);
    requests.add(request);
    return await handler(request);
  }
}

final class _StateStore implements LegacyAppStateStore {
  _StateStore(this.snapshot);

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
