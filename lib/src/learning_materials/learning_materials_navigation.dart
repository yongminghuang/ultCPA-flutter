import 'package:flutter/material.dart';

import '../main_tabs/main_tabs_models.dart';
import 'learning_materials_models.dart';

typedef LearningMaterialsLoginLauncher =
    Future<Map<String, dynamic>?> Function(BuildContext context);

typedef LearningMaterialsFeedLauncher =
    Future<void> Function(
      BuildContext context,
      LearningMaterialsFeedRequest request,
    );

typedef LearningMaterialsHtmlContentBuilder =
    Widget Function(BuildContext context, String html, Uri baseUri);

typedef LearningMaterialsVideoContentBuilder =
    Widget Function(BuildContext context, LearningMaterialsItem item);

typedef LearningMaterialsPaymentCallback =
    Future<bool> Function(
      BuildContext context,
      LearningMaterialsItem item,
      LearningMaterialsPaymentChannel channel,
    );

typedef LearningMaterialsShareCallback =
    Future<void> Function(
      BuildContext context,
      LearningMaterialsShareRequest request,
    );

typedef LearningMaterialsBannerCallback =
    Future<void> Function(BuildContext context, String jumpPage);

typedef LearningMaterialsDetailLauncher =
    Future<void> Function(
      BuildContext context,
      LearningMaterialsItem item,
      LearningMaterialsAppSnapshot appSnapshot,
    );

final class LearningMaterialsFeedRequest {
  LearningMaterialsFeedRequest({
    required this.module,
    required List<LearningMaterialsShelf> shelves,
    required this.initialTabIndex,
    required this.clickedIndex,
    required List<LearningMaterialsItem> snapshotItems,
    required this.appSnapshot,
    this.autoOpenItem,
  }) : shelves = List.unmodifiable(shelves),
       snapshotItems = List.unmodifiable(snapshotItems);

  final HomeModule module;
  final List<LearningMaterialsShelf> shelves;
  final int initialTabIndex;
  final int clickedIndex;
  final List<LearningMaterialsItem> snapshotItems;
  final LearningMaterialsItem? autoOpenItem;
  final LearningMaterialsAppSnapshot appSnapshot;

  int get safeInitialTabIndex {
    if (shelves.isEmpty) return 0;
    return initialTabIndex.clamp(0, shelves.length - 1);
  }

  List<LearningMaterialsItem> bootstrapForTab(int tabIndex) {
    if (tabIndex != safeInitialTabIndex || snapshotItems.isEmpty) {
      return const [];
    }
    return reorderLearningMaterialsClickedFirst(snapshotItems, clickedIndex);
  }
}
