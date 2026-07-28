# VIP Purchase Main Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking. This migration batch remains
> intentionally uncommitted; do not stage or commit.

**Goal:** Reproduce Android's Mine full-screen VIP selection and native
WeChat/Alipay checkout path without claiming the still-unmigrated payment
surfaces are complete.

**Architecture:** A focused `vip_purchase` feature owns immutable purchase
models, exact product/order requests, static marketing content, a typed native
gateway, and the full-screen page. Startup supplies the existing signed API,
legacy snapshot, login, web, and customer-service boundaries; MainTabs treats
only a confirmed paid result as a reason to refresh Mine.

**Tech Stack:** Flutter 3.32/Dart 3.8, Material widgets, Dio through
`AppApiClient`, MethodChannel, Kotlin, WeChat SDK 6.8.30, Alipay SDK 15.8.42,
MMKV, flutter_test.

---

### Task 1: Purchase models, formatting, and selection rules

**Files:**
- Create: `lib/src/vip_purchase/vip_purchase_models.dart`
- Create: `test/vip_purchase/vip_purchase_models_test.dart`

- [ ] **Step 1: Write failing model tests**

Define the wished-for public API in tests and pin these independent behaviors:

```dart
expect(VipProductType.skill.apiValue, 'skills_feature_package');
expect(VipProductType.svip.apiValue, 'level_member');
expect(VipProductType.course.apiValue, 'video_course');
expect(formatVipMoney(19.995), '20');
expect(formatVipMoney(19.9), '19.9');
expect(formatVipDailyPrice(totalPrice: 39.9, subjectCount: 2, days: 90),
    '仅¥0.22/科/天');
expect(resolveVipSkuDays('季卡', const []), 90);
expect(resolveInitialSubjectIndex(subjects, selectedMarketId: 7), 1);
expect(toggleAllVipSubjects({0, 1}, subjectCount: 2, fallbackIndex: 1), {1});
```

Also require strict product/common-SKU/order parsing, finite non-negative
prices, positive `productSkuId`, credential fields, immutable lists, expanded
type order `[svip, skill, course]`, skill-only fallback, and the six/three
Android privilege definitions.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\vip_purchase\vip_purchase_models_test.dart
```

Expected: `vip_purchase_models.dart` and its types do not exist.

- [ ] **Step 3: Implement the minimal immutable model API**

Create `VipPurchaseRequest.mine`, `VipProductType`, `VipPaymentChannel`,
`VipPurchaseResult`, `VipSubject`, `VipProduct`, `VipProductSku`,
`VipShopCartItem`, `VipCommonSku`, `VipWechatCredential`,
`VipPaymentOrder`, `VipBenefitLine`, and `VipPurchaseSession`. Add only the
formatting, parsing, privilege, initial-selection, remove-last-subject, and
select-all/clear helpers exercised in Step 1.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 2: Snapshot configuration and benefit display

**Files:**
- Modify: `lib/src/main_tabs/main_tabs_models.dart`
- Modify: `android/app/src/main/kotlin/com/xmzj/ult/agg/LegacyStartupBridge.kt`
- Modify: `test/main_tabs/main_tabs_models_test.dart`
- Modify: `test/network/method_channel_request_context_test.dart`
- Modify: `test/config/android_shell_config_test.dart`
- Modify: `lib/src/vip_purchase/vip_purchase_models.dart`
- Modify: `test/vip_purchase/vip_purchase_models_test.dart`

- [ ] **Step 1: Write failing snapshot and benefit tests**

Require `AppSnapshot.fromMap` to expose:

```text
categoryBodyJson
showWxPay (default true)
defaultPayType (default 1)
userBenefitsJson
```

Require the Android bridge source to read `accounting_category_body_json`,
App MMKV `showWxPay`, default-preference key
`module_loginandpay_default_pay`, and MMKV-lazy key
`key_mmkv_user_benefits_json` into the matching map names.

Port Android benefit cases into model tests: parse only current category and
level, split abstract `category:level:subject:type` codes, discard expired
entries, consolidate practice_skill + practice_speed + past_exams into
`答题技巧VIP`, order all before answering skills before course video, format
`有效期至 yyyy-MM-dd`, cap the header preview at two lines plus `查看更多`, and
resolve Mine source `2002` only for a non-full member with a practice package.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\main_tabs\main_tabs_models_test.dart test\network\method_channel_request_context_test.dart test\config\android_shell_config_test.dart test\vip_purchase\vip_purchase_models_test.dart
```

Expected: the snapshot fields and benefit helpers are missing.

- [ ] **Step 3: Add the snapshot values and pure benefit resolver**

Extend `AppSnapshot` without changing existing defaults. In Kotlin, use
`PreferenceManager.getDefaultSharedPreferences(context)` for the default pay
key and existing `appKv`/`dataKv` instances for MMKV values. Keep the benefit
resolver pure in `vip_purchase_models.dart`; it accepts raw JSON or live body,
the current category/level, and an injected clock.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 3: Exact purchase repository

**Files:**
- Create: `lib/src/vip_purchase/vip_purchase_repository.dart`
- Create: `test/vip_purchase/vip_purchase_repository_test.dart`

- [ ] **Step 1: Write failing session tests**

Use fake `AppApiClient` and `LegacyAppStateStore` implementations. Require
`loadSession(VipPurchaseRequest.mine)` to:

```text
read the selected category children
select matching marketId or first subject
GET /app/tempMedia/countGroupByLevelAndSubject
show [svip, skill, course] and select svip only for matching count > 0
fall back to skill-only when the count request/body is absent or malformed
GET /app/user/getUserBenefits only while logged in
fall back to cached benefit JSON if that optional request fails
resolve WeChat visibility/default channel and source 1020/2002
fall back to 会计实务(6), 经济法基础(7) when no valid children exist
```

Require null/non-list temp-media and benefit bodies to degrade without
failing the session; malformed required snapshot/category values use the
documented fallback.

- [ ] **Step 2: Run the session tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\vip_purchase\vip_purchase_repository_test.dart
```

Expected: `VipPurchaseDataSource` and `VipPurchaseRepository` are undefined.

- [ ] **Step 3: Implement session loading only**

Define this page-facing interface:

```dart
abstract interface class VipPurchaseDataSource {
  Future<VipPurchaseSession> loadSession(VipPurchaseRequest request);
  Future<VipSkuSelection> loadSkus({
    required VipPurchaseSession session,
    required VipProductType type,
    required List<VipSubject> subjects,
  });
  Future<VipPaymentOrder> createOrder({
    required VipPurchaseSession session,
    required VipPaymentChannel channel,
    required List<VipShopCartItem> shopCart,
  });
  Future<bool> confirmWechatPayment();
}
```

Implement only `loadSession`; leave other methods throwing
`UnimplementedError` until their RED tests exist.

- [ ] **Step 4: Run Step 2 and verify GREEN**

- [ ] **Step 5: Write failing SKU request tests**

Require selected subjects to issue sequential calls in the exact order:

```text
POST /app/product/v1/queryProduct per subject
POST /app/product/v1/queryCommonProductSku once with valid productIds
```

Assert the complete JSON maps including `productId: null` and
`loadSameTypeProducts: true`; accept object/list product bodies; ignore missing
product IDs; skip common-SKU I/O when no products survive; parse expiry minutes
for daily text; reject malformed common SKU bodies; and preserve returned SKU
and shop-cart ordering.

- [ ] **Step 6: Run Step 2 and verify the new tests fail for unimplemented methods**

- [ ] **Step 7: Implement `loadSkus` and run Step 2 GREEN**

- [ ] **Step 8: Write failing order and confirmation tests**

Require channel-specific paths, this exact payload, credential normalization,
and strict confirmation:

```dart
{
  'commodityId': null,
  'payPageSourceId': session.payPageSourceId,
  'shopCart': shopCart.map((item) => item.toJson()).toList(),
}
```

`confirmWechatPayment` must send a parameterless signed GET to
`/app/order/v2/getOrderPayStatus` and return true only for body string `成功`.
It returns false for cancel, pending, refunds, null, maps, and whitespace-only
variants.

- [ ] **Step 9: Run Step 2 and verify RED, implement order/status methods, then verify GREEN**

### Task 4: Typed Dart native-payment gateway

**Files:**
- Create: `lib/src/vip_purchase/vip_payment_gateway.dart`
- Create: `test/vip_purchase/vip_payment_gateway_test.dart`

- [ ] **Step 1: Write failing MethodChannel tests**

Require channel `com.xmzj.ult.agg/vip_payment`, `isWechatInstalled`,
`payWechat`, and `payAlipay`. Assert every WeChat credential key and the
Alipay `orderInfo` argument. Pin map results:

```text
success -> VipNativePaymentStatus.success
cancelled -> VipNativePaymentStatus.cancelled
failed + message -> failed with message
unavailable + message -> unavailable with message
null/unknown/malformed -> failed with 支付失败
PlatformException -> failed with platform message or 支付失败
```

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\vip_purchase\vip_payment_gateway_test.dart
```

Expected: the gateway library is missing.

- [ ] **Step 3: Implement `VipPaymentGateway` and `MethodChannelVipPaymentGateway`**

Keep all platform-map parsing in this file. The page receives only typed
`VipNativePaymentResult` values.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 5: Flutter-shell WeChat and Alipay bridge

**Files:**
- Create: `android/app/src/main/kotlin/com/xmzj/ult/agg/VipPaymentBridge.kt`
- Create: `android/app/src/main/kotlin/com/xmzj/ult/agg/wxapi/WXPayEntryActivity.kt`
- Modify: `android/app/src/main/kotlin/com/xmzj/ult/agg/MainActivity.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `android/app/build.gradle.kts`
- Modify: `test/config/android_shell_config_test.dart`

- [ ] **Step 1: Add failing Android-shell contract tests**

Require fixed dependency strings:

```kotlin
implementation("com.tencent.mm.opensdk:wechat-sdk-android:6.8.30")
implementation("com.alipay.sdk:alipaysdk-android:15.8.42@aar")
```

Require MainActivity registration, the exact channel and app ID, all seven
WeChat `PayReq` assignments, installed-app check, off-main-thread `PayTask`
execution, resultStatus mapping, one-in-flight guard, `WXPayEntryActivity`
package/class/handler, exported manifest declaration with `singleTop`, and the
WeChat package query.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\config\android_shell_config_test.dart
```

Expected: bridge/activity/dependency assertions fail.

- [ ] **Step 3: Implement the Kotlin bridge and manifest wiring**

`VipPaymentBridge` owns one pending WeChat MethodChannel result, rejects a
second payment, checks `api.isWXAppInstalled`, validates every credential,
registers/sends the request, and exposes a companion callback consumed by
`WXPayEntryActivity`. Alipay runs on a single background executor and posts the
typed map back through `activity.runOnUiThread`. Every result path clears its
in-flight state exactly once.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 6: Authoritative assets and marketing content

**Files:**
- Create: `assets/images/vip_purchase/` bitmap copies
- Create: `lib/src/vip_purchase/vip_purchase_marketing.dart`
- Create: `test/vip_purchase/vip_purchase_marketing_test.dart`
- Create: `test/vip_purchase/vip_purchase_assets_test.dart`
- Modify: `pubspec.yaml`

- [ ] **Step 1: Write failing marketing and asset tests**

Require exact Android pain points, social-work comparison rows, accounting
guarantee copy, joy-ledger/social-work/intermediate-economist student shares,
and category selection. Require these copied asset basenames to exist and be
declared by the directory asset entry:

```text
vip_open_accounting_layer_36.png
vip_open_accounting_layer_25.png
vip_open_accounting_asset_7cb1f20d.png
vip_open_accounting_asset_c18dffb6.png
vip_open_accounting_group_14.png
vip_open_accounting_group_14_v2.png
vip_open_accounting_layer_28.png
ic_promotion_add_customer_service.png
ic_default_avatar.png
icon_vip_wx.png
icon_vip_zfb.png
ic_vip_privilege_doc.png
ic_vip_privilege_practice.png
ic_vip_privilege_lock.png
ic_vip_privilege_real.png
ic_vip_privilege_chapter.png
ic_vip_privilege_card.png
ic_vip_privilege_video.png
ic_vip_privilege_folder.png
ic_vip_privilege_expert.png
```

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\vip_purchase\vip_purchase_marketing_test.dart test\vip_purchase\vip_purchase_assets_test.dart
```

Expected: marketing library/assets/directory declaration are missing.

- [ ] **Step 3: Copy only the listed Android bitmaps and implement static data**

Use the matching density-qualified source files under
`E:\workspace\ultCPA-android\ultCPA\src\main\res`, preserving pixels and
basenames. Add `assets/images/vip_purchase/` to `pubspec.yaml`. Do not modify
the reference project and do not copy hidden content-detail/common-question
artwork.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 7: Full-screen selection and checkout page

**Files:**
- Create: `lib/src/vip_purchase/vip_purchase_page.dart`
- Create: `test/vip_purchase/vip_purchase_page_test.dart`

- [ ] **Step 1: Write failing initial/rendering widget tests**

Build fake data-source/gateway controls and require:

```text
title and back control
retryable initial failure
logged-in benefit header only with display lines
skill-only vs expanded tabs and SVIP default
current-subject fallback
one-subject minimum
全选 then 清除
stale SKU completion ignored
first SKU selected and card switching
loading / 暂无商品 / enabled checkout text
six standard privileges and conditional three bonus privileges
visible category marketing blocks and hidden content/questions
floating customer-service and membership agreement actions
no overflow at 320x568 and 360x640
bottom bar respects view/system insets
```

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\vip_purchase\vip_purchase_page_test.dart
```

Expected: `VipPurchasePage` is undefined.

- [ ] **Step 3: Implement loading, selection, price, privilege, and marketing UI**

Use a `Scaffold`, transparent/warm AppBar, scroll view padded above a fixed
bottom area, wrapping chips, constrained horizontal price cards, Android
bitmap assets, and flat section containers. Keep state mutations guarded by a
selection generation and mounted checks. Do not add payment behavior before
its failing tests.

- [ ] **Step 4: Run Step 2 and verify GREEN**

- [ ] **Step 5: Write failing login/payment lifecycle tests**

Require logged-out pay to launch login once and create no order; cancelled
login to leave the session unchanged; successful login to reload session but
not auto-pay; empty cart to create no order; hidden/unavailable WeChat to show
the Android message; one order/SDK action while in flight; cancellation to be
silent; Alipay success to pop `paid`; WeChat native success to call server
confirmation before popping; pending/failure/exception to stay on page and
restore the button; and a disposed page to ignore late completions.

- [ ] **Step 6: Run Step 2 and verify the new tests RED**

- [ ] **Step 7: Implement the minimal checkout coordinator in the page**

Call `createOrder`, route credentials to the typed gateway, confirm WeChat,
show one SnackBar for non-cancel failures, and pop only on confirmed success.

- [ ] **Step 8: Run Step 2 and verify GREEN**

### Task 8: Mine, MainTabs, and Startup integration

**Files:**
- Modify: `lib/src/main_tabs/mine_tab_page.dart`
- Modify: `lib/src/main_tabs/main_tabs_page.dart`
- Modify: `lib/src/app/startup_app.dart`
- Modify: `test/main_tabs/mine_tab_page_test.dart`
- Modify: `test/main_tabs/main_tabs_page_test.dart`
- Modify: `test/app/startup_app_test.dart`

- [ ] **Step 1: Write failing route and single-flight tests**

Require `_VipFeaturePanel` to retain five features and add the Android bottom
row `解锁全部学习特权` with `开通会员`, keyed
`mine-vip-purchase`. Logged-out and logged-in Mine taps both open the page.
Repeated taps while the launcher Future is pending call it once. MainTabs
forwards the launcher and increments only Mine's reload token for `paid`, not
for back/cancel. Startup injects the real repository and gateway, pushes the
real page, reuses `PhoneLoginPage`, agreement web request, and customer service,
and returns to the same MainTabs instance.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\main_tabs\mine_tab_page_test.dart test\main_tabs\main_tabs_page_test.dart test\app\startup_app_test.dart
```

- [ ] **Step 3: Add typed launcher wiring and Startup construction**

Define `MineVipPurchaseLauncher` returning `Future<VipPurchaseResult?>`, add
Mine's busy guard, let MainTabs wrap the forwarded launcher and rebuild only
Mine on `paid`, and construct `VipPurchaseRepository` plus
`MethodChannelVipPaymentGateway` from Startup's existing `apiClient` and
`requestContext`.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 9: Public API and honest migration ledger

**Files:**
- Create: `test/vip_purchase/vip_purchase_exports_test.dart`
- Modify: `lib/ultcpa_flutter.dart`
- Modify: `lib/src/migration/activity_coverage.dart`
- Modify: `test/migration/activity_coverage_test.dart`
- Regenerate: `docs/migration/activity_coverage.csv`

- [ ] **Step 1: Write failing export and ledger tests**

Require public request/result/model/data-source/repository/gateway/page types.
Require `OpenVipMultiPayActivity` to move from pending to partial on
`VipPurchasePage` with evidence for Mine full-screen selection, product/SKU,
WeChat/Alipay, and explicit `VipPurchaseSuccessActivity`/other launchers
pending. Require Main evidence for the Mine CTA and paid-result refresh.
Require `VipPayPopup`, `OpenVipDaZhaoActivity`,
`VipDifferenceUpgradeActivity`, and `VipPurchaseSuccessActivity` to remain
pending and every existing shared-payment-dependent page to remain partial.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\vip_purchase\vip_purchase_exports_test.dart test\migration\activity_coverage_test.dart
```

- [ ] **Step 3: Export types, update only reviewed evidence, and regenerate CSV**

```powershell
dart run tool\migration\source_manifest.dart --android-root E:\workspace\ultCPA-android --out docs\migration\activity_coverage.csv
```

Read the generated rows and counts. The expected one-row status change is
`complete=14`, `partial=16`, `pending=39`, `external=6`, `removed=2`; stop and
inspect if actual counts differ.

- [ ] **Step 4: Run Step 2 and verify GREEN**

### Task 10: Full verification and fresh dev APK

**Files:**
- Verify all files changed above

- [ ] **Step 1: Format and prove formatting is stable**

Run `dart format` on changed Dart files, then:

```powershell
dart format --output=none --set-exit-if-changed lib test tool
```

- [ ] **Step 2: Run focused verification**

```powershell
.\tool\flutter_android21.ps1 test test\vip_purchase test\main_tabs test\app\startup_app_test.dart test\network\method_channel_request_context_test.dart test\config\android_shell_config_test.dart test\migration\activity_coverage_test.dart
```

Expected: every focused test passes with no warnings or uncaught errors.

- [ ] **Step 3: Run full verification**

```powershell
.\tool\flutter_android21.ps1 test
.\tool\flutter_android21.ps1 analyze
git diff --check
```

Expected: zero test failures, Analyzer reports no issues, and diff check emits
no whitespace errors.

- [ ] **Step 4: Build and inspect a fresh dev debug APK**

```powershell
.\tool\flutter_android21.ps1 build apk --debug --flavor dev
```

Record `build\app\outputs\flutter-apk\app-dev-debug.apk` byte size and
SHA-256, verify the migration CSV counts/critical rows, and confirm the staged
index remains empty. Do not stage or commit.
