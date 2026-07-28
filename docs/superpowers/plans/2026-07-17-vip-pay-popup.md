# Shared VIP Pay Surfaces Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking. This ongoing migration worktree is
> intentionally uncommitted; do not stage or commit.

**Goal:** Reproduce Android's reachable `VipPayPopup`, retain Android's
full-screen six-paper payment path, and make both presentations the default
payment paths for the five already-migrated locked feature families.

**Architecture:** Extend the existing VIP purchase request with attributed
popup and full-screen calls, extract the proven order/native-confirmation state
machine into a shared coordinator, and build a dedicated 82%-height modal sheet
on the same repository and gateway. Startup supplies exact Android conversion
IDs and presentation types while feature pages remain responsible for
post-payment entitlement refresh.

**Tech Stack:** Flutter 3.32/Dart 3.8, Material modal bottom sheets, signed
`AppApiClient`, native WeChat/Alipay MethodChannel gateway, flutter_test.

---

### Task 1: Popup attribution and shared checkout state machine

**Files:**
- Modify: `lib/src/vip_purchase/vip_purchase_models.dart`
- Modify: `test/vip_purchase/vip_purchase_models_test.dart`
- Create: `lib/src/vip_purchase/vip_checkout_coordinator.dart`
- Create: `test/vip_purchase/vip_checkout_coordinator_test.dart`

- [ ] **Step 1: Write failing popup-request tests**

Require a named popup request and the six source constants:

```dart
expect(VipPayEntry.fast300.conversionEntryId, 1010);
expect(VipPayEntry.secretPaperList.conversionEntryId, 1011);
expect(VipPayEntry.secretPaperBottom.conversionEntryId, 1012);
expect(VipPayEntry.smartCard.conversionEntryId, 1013);
expect(VipPayEntry.preExamSixPaper.conversionEntryId, 1014);
expect(VipPayEntry.pastExams.conversionEntryId, 1021);

const request = VipPurchaseRequest.popup(
  entry: VipPayEntry.fast300,
  defaultProductType: VipProductType.skill,
);
expect(request.normalPayPageSourceId, 1010);
expect(request.differencePayPageSourceId, 1010);
expect(request.defaultProductType, VipProductType.skill);
```

- [ ] **Step 2: Run the model test and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\vip_purchase\vip_purchase_models_test.dart
```

Expected: `VipPayEntry` and `VipPurchaseRequest.popup` are undefined.

- [ ] **Step 3: Implement the enum and popup constructor, then verify GREEN**

Keep `VipPurchaseRequest.mine` unchanged. The popup constructor assigns
`entry.conversionEntryId` to both source fields so benefit parsing never
rewrites caller attribution.

- [ ] **Step 4: Write failing coordinator tests**

Define these immutable outcomes:

```dart
enum VipCheckoutStatus { paid, cancelled, failed }

final class VipCheckoutOutcome {
  const VipCheckoutOutcome._(this.status, this.message);
  const VipCheckoutOutcome.paid()
      : this._(VipCheckoutStatus.paid, '');
  const VipCheckoutOutcome.cancelled()
      : this._(VipCheckoutStatus.cancelled, '');
  const VipCheckoutOutcome.failed(String message)
      : this._(VipCheckoutStatus.failed, message);
}
```

Pin every branch: empty cart makes no call; unavailable WeChat returns
`您没有安装微信` before order creation; order exceptions become their trimmed
message; native cancellation is silent; native failed/unavailable preserves a
non-empty message or uses `支付失败`; Alipay success is paid; WeChat success is
paid only after `confirmWechatPayment()` returns true; false confirmation uses
`支付结果确认失败，请稍后重试`; malformed channel credentials are rejected by the
existing strict page/data-source boundary.

- [ ] **Step 5: Run the coordinator test and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\vip_purchase\vip_checkout_coordinator_test.dart
```

- [ ] **Step 6: Implement the minimal coordinator and verify GREEN**

The coordinator receives `VipPurchaseDataSource` and `VipPaymentGateway` and
exposes:

```dart
Future<VipCheckoutOutcome> checkout({
  required VipPurchaseSession session,
  required VipPaymentChannel channel,
  required List<VipShopCartItem> shopCart,
});
```

### Task 2: Keep full-screen checkout on the shared coordinator

**Files:**
- Modify: `lib/src/vip_purchase/vip_purchase_page.dart`
- Modify: `test/vip_purchase/vip_purchase_page_test.dart`

- [ ] **Step 1: Add a failing regression assertion for coordinator messages**

Add coverage proving unavailable WeChat creates no order, cancellation remains
silent, failed native results show one message, and server confirmation failure
restores checkout. These tests must use the public page, not the coordinator
directly.

- [ ] **Step 2: Run the page test and confirm the new assertion fails for the intended old branch**

```powershell
.\tool\flutter_android21.ps1 test test\vip_purchase\vip_purchase_page_test.dart
```

- [ ] **Step 3: Replace private checkout duplication with the coordinator**

The page keeps its login gate, loading state, success-summary load, and
navigation. It maps `paid` to `_loadSuccessSummary`, ignores `cancelled`, and
shows the coordinator message for `failed`.

- [ ] **Step 4: Run coordinator, gateway, repository, and page tests GREEN**

```powershell
.\tool\flutter_android21.ps1 test test\vip_purchase\vip_checkout_coordinator_test.dart test\vip_purchase\vip_payment_gateway_test.dart test\vip_purchase\vip_purchase_repository_test.dart test\vip_purchase\vip_purchase_page_test.dart
```

### Task 3: Android `VipPayPopup` sheet

**Files:**
- Create: `lib/src/vip_purchase/vip_pay_sheet.dart`
- Create: `test/vip_purchase/vip_pay_sheet_test.dart`

- [ ] **Step 1: Write failing sheet model and widget tests**

Require `showVipPaySheet(...)` and `VipPaySheet` to provide:

```dart
Future<VipPurchaseResult?> showVipPaySheet(
  BuildContext context, {
  required VipPurchaseRequest request,
  required VipPurchaseDataSource dataSource,
  required VipPaymentGateway paymentGateway,
  VipPurchaseLoginLauncher? loginLauncher,
  VipPurchaseActionLauncher? agreementLauncher,
});
```

Pin an 82%-height, rounded-top modal with close control; visible product tabs;
selected-market subject; select-all/clear; stale SKU protection; horizontal
price cards; standard/bonus privileges; hidden WeChat channel; saved channel
default; `加载中`, `请选择科目`, and `暂无商品`; fixed safe-area checkout; agreement
callback; and no overflow at 320x568 and 360x640.

Pin lifecycle and payment behavior: session retry, single-flight checkout,
login then session reload without automatic ordering, silent cancellation,
failure recovery, late completion after disposal, confirmed payment dismissing
the sheet, generic success-summary fallback, full-screen
`VipPurchaseSuccessPage`, and a final `VipPurchaseResult.paid` only after its
finish action.

- [ ] **Step 2: Run the sheet test and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\vip_purchase\vip_pay_sheet_test.dart
```

- [ ] **Step 3: Implement selection/session state before checkout**

Use the existing selection helpers and repository. Each type/subject change
increments a generation; only the current generation may update visible SKUs.
The first valid SKU is selected and no empty cart can enable checkout.

- [ ] **Step 4: Run non-payment sheet tests GREEN**

- [ ] **Step 5: Implement checkout, login, presenter, and success routing**

The presenter awaits `showModalBottomSheet`, loads success copy after a paid
sheet result, pushes `VipPurchaseSuccessPage`, and returns `paid` after that
page invokes its finish callback. All navigation checks `context.mounted`.

- [ ] **Step 6: Run the complete sheet and VIP purchase test directories GREEN**

```powershell
.\tool\flutter_android21.ps1 test test\vip_purchase
```

### Task 4: Typed unlock triggers and post-payment entitlement refresh

**Files:**
- Modify: `lib/src/fast_practice/fast_practice_landing_page.dart`
- Modify: `lib/src/pre_exam_six_paper/pre_exam_six_paper_landing_page.dart`
- Modify: `lib/src/pre_exam_six_paper/pre_exam_six_paper_entry_page.dart`
- Modify: `lib/src/pre_exam_secret_paper/pre_exam_secret_paper_page.dart`
- Modify: `lib/src/smart_card/smart_card_page.dart`
- Modify: matching tests under `test/fast_practice/`,
  `test/pre_exam_six_paper/`, `test/pre_exam_secret_paper/`, and
  `test/smart_card/`

- [ ] **Step 1: Write failing unlock-contract tests**

Change the fast and six-paper landing callbacks to `FutureOr<void>` and invoke
them through `Future.sync`. Their entry pages await the callback, guard
duplicate actions, and resolve the destination again afterward. Startup
supplies the global duplicate-presentation protection.
Define:

```dart
enum PreExamSecretPaperUnlockSource { lockedCard, bottomAction }

typedef PreExamSecretPaperUnlockLauncher = FutureOr<void> Function(
  PreExamSecretPaperUnlockSource source,
);
```

Require the secret page to send the correct trigger, reload only after the
callback completes, and restore its CTA after errors. Require Smart Card and
past exams to reload entitlement after callback completion. Require fast and
six-paper entry pages to transition from landing to their repository-resolved
unlocked destination only after callback completion. Preserve every existing
injected launcher behavior.

- [ ] **Step 2: Run affected feature tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\fast_practice test\pre_exam_six_paper test\pre_exam_secret_paper test\smart_card
```

- [ ] **Step 3: Implement only the typed callback/lifecycle changes**

Do not add payment imports to feature modules. They expose trigger intent;
Startup owns payment presentation and source mapping.

- [ ] **Step 4: Run Step 2 GREEN**

### Task 5: Startup production wiring and exact source IDs

**Files:**
- Modify: `lib/src/app/startup_app.dart`
- Modify: `test/app/startup_app_test.dart`
- Modify: `test/past_exams/past_exams_page_test.dart`

- [ ] **Step 1: Write failing Startup routing tests**

For each reachable page, omit its injected unlock launcher, tap the locked
action, and require the Android presentation plus the exact entry:

```text
fast300=1010
secret locked card=1011
secret bottom=1012
smart card=1013
six paper=1014 (full-screen `VipPurchasePage`)
past exams=1021
```

Pin one global shared-payment single-flight guard. Require injected feature
launchers to bypass the default presenter. Require both secret-paper entries to
construct popup requests with `defaultProductType=skill`. Require confirmed
payment to rebuild MainTabs and let the active feature re-read entitlement;
dismiss/cancel stays on the feature and must not fabricate paid state.

- [ ] **Step 2: Run Startup and affected page tests and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\app\startup_app_test.dart test\past_exams\past_exams_page_test.dart
```

- [ ] **Step 3: Wire the default launcher in Startup**

Add a shared presentation guard and two helpers:

```dart
Future<VipPurchaseResult?> _openVipPaySheet(
  BuildContext context,
  VipPayEntry entry,
  {VipProductType? defaultProductType},
) async;

Future<VipPurchaseResult?> _openVipPurchasePage(
  BuildContext context,
  VipPayEntry entry,
) async;
```

The popup helper constructs `VipPurchaseRequest.popup(...)`; the full-screen
helper constructs `VipPurchaseRequest.fullScreen(...)`. Both reuse the existing
repository/gateway/login/agreement dependencies and clear the shared guard in
`finally`. A paid result increments the MainTabs revision but does not remove
the feature route. Bind these helpers only when the corresponding feature
override is null.

- [ ] **Step 4: Run Step 2 plus all feature directories GREEN**

### Task 6: Public exports and honest migration ledger

**Files:**
- Modify: `lib/ultcpa_flutter.dart`
- Modify: `test/vip_purchase/vip_purchase_exports_test.dart`
- Modify: `lib/src/migration/activity_coverage.dart`
- Modify: `test/migration/activity_coverage_test.dart`
- Regenerate: `docs/migration/activity_coverage.csv`

- [ ] **Step 1: Write failing export and ledger tests**

Require public exports for the checkout coordinator and pay sheet. Remove
`real payment pending` only from the now-wired activity rows. Remove
`VipPayPopup pending` from `OpenVipMultiPayActivity` evidence because that row
already represents the shared product/order implementation, while explicitly
recording that six-paper reaches it as a full-screen page. Keep
`QuestionPackagePayDialog`, difference upgrade, `OpenVipDaZhaoActivity`, Home
marketing float, video paywalls, and other unrelated launchers explicitly
pending. Status counts are expected to remain unchanged unless the regenerated
manifest proves otherwise.

- [ ] **Step 2: Run and verify RED**

```powershell
.\tool\flutter_android21.ps1 test test\vip_purchase\vip_purchase_exports_test.dart test\migration\activity_coverage_test.dart
```

- [ ] **Step 3: Export, update evidence, and regenerate CSV**

```powershell
dart run tool\migration\source_manifest.dart --android-root E:\workspace\ultCPA-android --out docs\migration\activity_coverage.csv
```

- [ ] **Step 4: Run Step 2 GREEN**

### Task 7: Full verification and fresh dev APK

**Files:**
- Verify all files above

- [ ] **Step 1: Format and check formatting**

```powershell
dart format lib\src\vip_purchase lib\src\app lib\src\fast_practice lib\src\pre_exam_six_paper lib\src\pre_exam_secret_paper lib\src\smart_card test\vip_purchase test\app test\fast_practice test\pre_exam_six_paper test\pre_exam_secret_paper test\smart_card lib\ultcpa_flutter.dart
dart format --output=none --set-exit-if-changed lib test tool
```

- [ ] **Step 2: Run focused and full verification**

```powershell
.\tool\flutter_android21.ps1 test test\vip_purchase test\app\startup_app_test.dart test\fast_practice test\pre_exam_six_paper test\pre_exam_secret_paper test\smart_card test\past_exams test\migration\activity_coverage_test.dart
.\tool\flutter_android21.ps1 test
.\tool\flutter_android21.ps1 analyze
git diff --check
```

- [ ] **Step 3: Build and fingerprint a fresh APK**

```powershell
.\tool\flutter_android21.ps1 build apk --debug --flavor dev
Get-Item build\app\outputs\flutter-apk\app-dev-debug.apk
Get-FileHash -Algorithm SHA256 build\app\outputs\flutter-apk\app-dev-debug.apk
```

Record the absolute path, length, and SHA-256. Do not stage or commit the dirty
worktree.
