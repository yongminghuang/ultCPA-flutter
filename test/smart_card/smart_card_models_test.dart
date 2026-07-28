import 'package:flutter_test/flutter_test.dart';
import 'package:ultcpa_flutter/src/main_tabs/main_tabs_models.dart';
import 'package:ultcpa_flutter/src/skill_mnemonics/skill_mnemonics_models.dart';
import 'package:ultcpa_flutter/src/smart_card/smart_card_models.dart';

void main() {
  test('builds the exact flat first-page request', () {
    const request = SmartCardRequest(module: _module);

    expect(request.isValid, isTrue);
    expect(request.isNested, isFalse);
    expect(request.queryParameters, {
      'pageNum': 1,
      'pageSize': 200,
      'shelfId': 51,
    });
  });

  test('builds the exact nested leaf request', () {
    const request = SmartCardRequest(module: _module, shelfId: 901);

    expect(request.isValid, isTrue);
    expect(request.isNested, isTrue);
    expect(request.queryParameters, {
      'pageNum': 1,
      'pageSize': 200,
      'modelId': 51,
      'shelfId': 901,
    });
  });

  test('rejects invalid IDs only when creating network parameters', () {
    const invalidModule = SmartCardRequest(
      module: HomeModule(id: 0, name: '技巧卡片', page: '技巧卡片', tag: ''),
    );
    const invalidShelf = SmartCardRequest(module: _module, shelfId: -1);

    expect(invalidModule.isValid, isFalse);
    expect(invalidShelf.isValid, isFalse);
    expect(() => invalidModule.queryParameters, throwsArgumentError);
    expect(() => invalidShelf.queryParameters, throwsArgumentError);
  });

  test('entry preserves VIP and an optional prefetched catalog', () {
    final catalog = SkillMnemonicsCatalog.fromBody(
      const {
        'records': [
          {'skillId': '11', 'text': '先读题干'},
        ],
      },
      freeCount: 3,
      isVip: true,
    );
    final entry = SmartCardEntry(
      SmartCardEntryDestination.page,
      isVip: true,
      catalog: catalog,
    );

    expect(entry.destination, SmartCardEntryDestination.page);
    expect(entry.isVip, isTrue);
    expect(entry.catalog, same(catalog));
    expect(
      const SmartCardEntry(SmartCardEntryDestination.unavailable).catalog,
      isNull,
    );
  });
}

const _module = HomeModule(id: 51, name: '技巧卡片', page: '技巧卡片', tag: '');
