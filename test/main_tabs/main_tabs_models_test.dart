import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';

void main() {
  test('parses the persisted mnemonic free count with Android default', () {
    expect(
      AppSnapshot.fromMap({'skillFormulaFreeCount': '5'}).skillFormulaFreeCount,
      5,
    );
    expect(AppSnapshot.fromMap(const {}).skillFormulaFreeCount, 3);
  });

  test('parses the persisted practice free count with Android default', () {
    expect(
      AppSnapshot.fromMap({
        'skillQuestionFreeCount': '9',
      }).skillQuestionFreeCount,
      9,
    );
    expect(AppSnapshot.fromMap(const {}).skillQuestionFreeCount, 5);
  });

  test('parses Mine web snapshot fields with Android defaults', () {
    final snapshot = AppSnapshot.fromMap(const {
      'collectBookH5Url': '  https://example.com/collect  ',
      'accessToken': 'access-token',
      'commissionRate': 0.25,
      'isTestEnvironment': true,
    });

    expect(snapshot.collectBookH5Url, '  https://example.com/collect  ');
    expect(snapshot.accessToken, 'access-token');
    expect(snapshot.commissionRate, '0.25');
    expect(snapshot.isTestEnvironment, isTrue);

    final defaults = AppSnapshot.fromMap(const {});
    expect(defaults.collectBookH5Url, isEmpty);
    expect(defaults.accessToken, isEmpty);
    expect(defaults.commissionRate, isEmpty);
    expect(defaults.isTestEnvironment, isFalse);
  });

  test('parses VIP purchase snapshot fields with Android defaults', () {
    final snapshot = AppSnapshot.fromMap(const {
      'categoryBodyJson': '{"joy-ledger":[]}',
      'showWxPay': false,
      'defaultPayType': '2',
      'userBenefitsJson': '[{"benefitsCode":"KJ_MEMBER_L1_3M"}]',
    });

    expect(snapshot.categoryBodyJson, '{"joy-ledger":[]}');
    expect(snapshot.showWxPay, isFalse);
    expect(snapshot.defaultPayType, 2);
    expect(snapshot.userBenefitsJson, '[{"benefitsCode":"KJ_MEMBER_L1_3M"}]');

    final defaults = AppSnapshot.fromMap(const {});
    expect(defaults.categoryBodyJson, isEmpty);
    expect(defaults.showWxPay, isTrue);
    expect(defaults.defaultPayType, 1);
    expect(defaults.userBenefitsJson, isEmpty);
  });
}
