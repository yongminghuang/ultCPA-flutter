import 'dart:async';

import 'package:flutter/material.dart';

import '../authentication/phone_login_page.dart';
import '../vip_purchase/vip_purchase_models.dart';
import 'course_tab_page.dart';
import 'home_tab_page.dart';
import 'main_tabs_repository.dart';
import 'mine_tab_page.dart';

typedef PhoneLoginLauncher =
    Future<Map<String, dynamic>?> Function(BuildContext context);

final class MainTabsPage extends StatefulWidget {
  const MainTabsPage({
    required this.dataSource,
    this.loginLauncher,
    this.moduleLauncher,
    this.courseMediaLauncher,
    this.learningMaterialsSectionBuilder,
    this.mineAppUpdateLauncher,
    this.mineCustomerServiceLauncher,
    this.mineReviewLauncher,
    this.mineProfileLauncher,
    this.minePurchaseHistoryLauncher,
    this.mineSettingsLauncher,
    this.mineVipPurchaseLauncher,
    this.mineWebLauncher,
    super.key,
  });

  final MainTabsDataSource dataSource;
  final PhoneLoginLauncher? loginLauncher;
  final HomeModuleLauncher? moduleLauncher;
  final CourseMediaLauncher? courseMediaLauncher;
  final LearningMaterialsSectionBuilder? learningMaterialsSectionBuilder;
  final MineAppUpdateLauncher? mineAppUpdateLauncher;
  final MineCustomerServiceLauncher? mineCustomerServiceLauncher;
  final MineReviewLauncher? mineReviewLauncher;
  final MineProfileLauncher? mineProfileLauncher;
  final MinePurchaseHistoryLauncher? minePurchaseHistoryLauncher;
  final MineSettingsLauncher? mineSettingsLauncher;
  final MineVipPurchaseLauncher? mineVipPurchaseLauncher;
  final MineWebLauncher? mineWebLauncher;

  @override
  State<MainTabsPage> createState() => _MainTabsPageState();
}

final class _MainTabsPageState extends State<MainTabsPage> {
  static const _selectedColor = Color(0xFF237DED);
  static const _unselectedColor = Color(0xFFB3B3B3);

  int _selectedIndex = 0;
  int _mineReloadToken = 0;
  int _selectionRevision = 0;
  bool _openingLogin = false;
  bool _openingHomeVipPurchase = false;
  late final List<Widget?> _pages = [_buildHomePage(), null, null];

  HomeTabPage _buildHomePage() {
    return HomeTabPage(
      dataSource: widget.dataSource,
      onSelectionChanged: _handleSelectionChanged,
      onVipSelected: widget.mineVipPurchaseLauncher == null
          ? null
          : () => unawaited(_openVipPurchaseFromHome()),
      moduleLauncher: widget.moduleLauncher,
      learningMaterialsSectionBuilder: widget.learningMaterialsSectionBuilder,
    );
  }

  CourseTabPage _buildCoursePage() {
    return CourseTabPage(
      dataSource: widget.dataSource,
      selectionRevision: _selectionRevision,
      mediaLauncher: widget.courseMediaLauncher,
    );
  }

  void _selectTab(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
      _pages[index] ??= switch (index) {
        1 => _buildCoursePage(),
        2 => _buildMinePage(),
        _ => _buildHomePage(),
      };
    });
  }

  void _handleSelectionChanged() {
    setState(() {
      _selectionRevision += 1;
      if (_pages[1] != null) _pages[1] = _buildCoursePage();
      if (_pages[2] != null) _pages[2] = _buildMinePage();
    });
  }

  MineTabPage _buildMinePage() {
    return MineTabPage(
      dataSource: widget.dataSource,
      reloadToken: _mineReloadToken,
      selectionRevision: _selectionRevision,
      onLoginRequested: _loginFromMine,
      appUpdateLauncher: widget.mineAppUpdateLauncher,
      customerServiceLauncher: widget.mineCustomerServiceLauncher,
      profileLauncher: widget.mineProfileLauncher,
      purchaseHistoryLauncher: widget.minePurchaseHistoryLauncher,
      reviewLauncher: widget.mineReviewLauncher,
      settingsLauncher: widget.mineSettingsLauncher,
      vipPurchaseLauncher: widget.mineVipPurchaseLauncher == null
          ? null
          : _openVipPurchaseFromMine,
      webLauncher: widget.mineWebLauncher,
    );
  }

  Future<VipPurchaseResult?> _openVipPurchaseFromMine(
    BuildContext context,
  ) async {
    final launcher = widget.mineVipPurchaseLauncher;
    if (launcher == null) return null;
    final result = await launcher(context);
    if (!mounted || result != VipPurchaseResult.paid) return result;
    setState(() {
      _selectedIndex = 0;
      _mineReloadToken += 1;
      _pages[2] = _buildMinePage();
    });
    return result;
  }

  Future<void> _openVipPurchaseFromHome() async {
    final launcher = widget.mineVipPurchaseLauncher;
    if (launcher == null || _openingHomeVipPurchase) return;
    _openingHomeVipPurchase = true;
    try {
      final result = await launcher(context);
      if (!mounted || result != VipPurchaseResult.paid) return;
      setState(() {
        _mineReloadToken += 1;
        if (_pages[2] != null) _pages[2] = _buildMinePage();
      });
    } finally {
      _openingHomeVipPurchase = false;
    }
  }

  Future<void> _loginFromMine() async {
    if (_openingLogin) return;
    _openingLogin = true;
    try {
      final result =
          await (widget.loginLauncher?.call(context) ??
              Navigator.of(context).pushNamed(PhoneLoginPage.routeName));
      if (!mounted || result == null) return;
      setState(() {
        _mineReloadToken += 1;
        _pages[2] = _buildMinePage();
      });
    } finally {
      _openingLogin = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages
            .map((page) => page ?? const SizedBox.expand())
            .toList(growable: false),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _selectTab,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: _selectedColor,
        unselectedItemColor: _unselectedColor,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        elevation: 8,
        items: [
          BottomNavigationBarItem(
            icon: _navigationIcon('ic_home_main_unselected.png'),
            activeIcon: _navigationIcon('ic_home_main_selected.png'),
            label: '技巧练题',
          ),
          BottomNavigationBarItem(
            icon: _navigationIcon('ic_home_short_unselected.png'),
            activeIcon: _navigationIcon('ic_home_short_selected.png'),
            label: '技巧课程',
          ),
          BottomNavigationBarItem(
            icon: _navigationIcon('ic_home_mine_unselected.png'),
            activeIcon: _navigationIcon('ic_home_mine_selected.png'),
            label: '我的',
          ),
        ],
      ),
    );
  }
}

Widget _navigationIcon(String fileName) {
  return Image.asset(
    'assets/images/main_tabs/$fileName',
    width: 25,
    height: 25,
    fit: BoxFit.contain,
  );
}
