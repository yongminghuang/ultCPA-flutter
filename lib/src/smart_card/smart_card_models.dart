import '../main_tabs/main_tabs_models.dart';
import '../skill_mnemonics/skill_mnemonics_models.dart';

final class SmartCardRequest {
  const SmartCardRequest({required this.module, this.shelfId = 0});

  final HomeModule module;
  final int shelfId;

  bool get isNested => shelfId > 0;

  bool get isValid => module.id > 0 && shelfId >= 0;

  Map<String, dynamic> get queryParameters {
    if (module.id <= 0) {
      throw ArgumentError.value(module.id, 'module.id', '必须大于 0');
    }
    if (shelfId < 0) {
      throw ArgumentError.value(shelfId, 'shelfId', '不能小于 0');
    }
    return isNested
        ? {
            'pageNum': 1,
            'pageSize': 200,
            'modelId': module.id,
            'shelfId': shelfId,
          }
        : {'pageNum': 1, 'pageSize': 200, 'shelfId': module.id};
  }
}

enum SmartCardEntryDestination { page, unavailable, empty }

final class SmartCardEntry {
  const SmartCardEntry(this.destination, {this.isVip = false, this.catalog});

  final SmartCardEntryDestination destination;
  final bool isVip;
  final SkillMnemonicsCatalog? catalog;
}
