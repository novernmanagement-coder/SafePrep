import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'app_state.dart';
import 'app_state_persistence.dart';
import 'mixpanel_service.dart';

// ─────────────────────────────────────────────────────────────────
// Product IDs — must match App Store Connect exactly
// ─────────────────────────────────────────────────────────────────
const String kProductSevenDay = 'SafePrepSevenDay'; // $4.99 — 7 days
const String kProductFourteenDay = 'SafePrepFourteenDay'; // $8.99 — 14 days
const String kProductUnlockApp = 'SafePrepUnlock'; // $9.99 — lifetime
const String kProductUpgrade =
    'com.geraldmiller.safeprep.upgrade'; // $4.99 — upgrade to lifetime
const String kProductRenewal =
    'SafePrepRenewalWeek'; // $2.99 — +7 days, existing purchasers only
// TODO: confirm this product ID has actually been created in App
// Store Connect before shipping — buyRenewal() will resolve
// productNotFound until it exists there. IMPORTANT: must be created
// as a CONSUMABLE product type, not non-consumable — it's meant to
// be bought repeatedly, and _purchase() below now routes it through
// buyConsumable() specifically because of that.

// How long a buy* call will wait for StoreKit to resolve (purchased,
// canceled, or errored) before giving up and returning IAPResult.timeout.
// Prevents a nav bar / button loading spinner from getting stuck forever
// if the purchase stream never emits for some edge case (e.g. app
// backgrounded mid-purchase and StoreKit's callback gets lost).
const Duration _purchaseTimeout = Duration(seconds: 90);

// ─────────────────────────────────────────────────────────────────
// IAPService
// ─────────────────────────────────────────────────────────────────
class IAPService {
  IAPService._();
  static final IAPService instance = IAPService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  ProductDetails? _sevenDayProduct;
  ProductDetails? _fourteenDayProduct;
  ProductDetails? _unlockProduct;
  ProductDetails? _upgradeProduct;
  ProductDetails? _renewalProduct;

  bool _available = false;
  bool get isAvailable => _available;

  // Tracks in-flight purchases so _onPurchaseUpdate can resolve the
  // Future that the calling buy* method is awaiting. Keyed by product ID
  // — this app only ever has one purchase in flight per product at a
  // time, since buy buttons disable themselves while loading.
  final Map<String, Completer<IAPResult>> _pendingPurchases = {};

  // ── Initialization ──────────────────────────────────────────
  Future<void> initialize() async {
    _available = await _iap.isAvailable();
    if (!_available) return;

    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (e) => debugPrint('IAP stream error: $e'),
    );

    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    final response = await _iap.queryProductDetails({
      kProductSevenDay,
      kProductFourteenDay,
      kProductUnlockApp,
      kProductUpgrade,
      kProductRenewal,
    });

    if (response.error != null) {
      debugPrint('IAP product load error: ${response.error}');
      return;
    }

    for (final p in response.productDetails) {
      switch (p.id) {
        case kProductSevenDay:
          _sevenDayProduct = p;
          break;
        case kProductFourteenDay:
          _fourteenDayProduct = p;
          break;
        case kProductUnlockApp:
          _unlockProduct = p;
          break;
        case kProductUpgrade:
          _upgradeProduct = p;
          break;
        case kProductRenewal:
          _renewalProduct = p;
          break;
      }
    }

    debugPrint(
      'IAP products loaded: ${response.productDetails.map((p) => p.id).toList()}',
    );
  }

  void dispose() {
    _subscription?.cancel();
  }

  // ── Purchase stream handler ─────────────────────────────────
  // This is where the ACTUAL outcome of a purchase becomes known —
  // buyNonConsumable()/buyConsumable() only confirm the request was
  // submitted, not whether the person completed, canceled, or hit an
  // error in the App Store sheet. Every outcome here both resolves
  // the Completer the calling buy* method is waiting on AND logs a
  // Mixpanel event, so purchase outcomes are visible in analytics,
  // not just taps.
  void _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      final completer = _pendingPurchases[purchase.productID];

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _handleSuccess(purchase);
          MixpanelService.instance.track(
            'purchase_completed',
            properties: {
              'product_id': purchase.productID,
              'restored': purchase.status == PurchaseStatus.restored,
            },
          );
          completer?.complete(IAPResult.success);
          _pendingPurchases.remove(purchase.productID);
          break;

        case PurchaseStatus.error:
          debugPrint('IAP error: ${purchase.error?.message}');
          MixpanelService.instance.track(
            'purchase_failed',
            properties: {
              'product_id': purchase.productID,
              'error': purchase.error?.message ?? 'unknown',
            },
          );
          completer?.complete(IAPResult.error);
          _pendingPurchases.remove(purchase.productID);
          break;

        case PurchaseStatus.canceled:
          debugPrint('IAP canceled: ${purchase.productID}');
          MixpanelService.instance.track(
            'purchase_canceled',
            properties: {'product_id': purchase.productID},
          );
          completer?.complete(IAPResult.canceled);
          _pendingPurchases.remove(purchase.productID);
          break;

        case PurchaseStatus.pending:
          debugPrint('IAP pending: ${purchase.productID}');
          // Don't resolve yet — StoreKit is still working (e.g. Ask to
          // Buy family approval). The caller keeps waiting up to
          // _purchaseTimeout.
          break;
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _handleSuccess(PurchaseDetails purchase) async {
    final state = AppState();

    // Renewal is handled separately from every other product below —
    // it does NOT reset purchaseDate to now (that would hand back a
    // full fresh 7 days regardless of how little time was left,
    // silently deleting whatever they were about to lose). Instead
    // it anchors the new purchaseDate at the CURRENT expiry (or now,
    // only if access had already fully lapsed) so the +7 days from
    // that point preserves any remaining time, per the earlier
    // "currentExpiry + 7, not now + 7" decision.
    if (purchase.productID == kProductRenewal) {
      final currentExpiry = state.expiryDate;
      final anchor =
          (currentExpiry != null && currentExpiry.isAfter(DateTime.now()))
          ? currentExpiry
          : DateTime.now();
      state.purchaseDate = anchor;
      // purchaseType stays sevenDay — a renewal doesn't change the
      // plan shape, just extends it.
      state.purchaseType = PurchaseType.sevenDay;
      // Let the HomePage renewal explainer fire again on a future
      // cycle instead of staying permanently seen after one renewal.
      state.hasSeenRenewalExplainer = false;
      await AppStatePersistence.save();
      debugPrint('IAP renewal success: new expiry ${state.expiryDate}');
      return;
    }

    // Clear trial history on first purchase only
    if (!state.hasUnlockedApp) {
      state.testHistory.clear();
      state.clearCurriculumProgress();
      state.hasSeenIntro = false;
    }

    state.hasUnlockedApp = true;
    state.purchaseDate = DateTime.now();

    switch (purchase.productID) {
      case kProductSevenDay:
        state.purchaseType = PurchaseType.sevenDay;
        break;
      case kProductFourteenDay:
        state.purchaseType = PurchaseType.fourteenDay;
        break;
      case kProductUnlockApp:
        state.purchaseType = PurchaseType.lifetime;
        break;
      case kProductUpgrade:
        // Upgrade — keep purchase date, just elevate to lifetime
        state.purchaseType = PurchaseType.lifetime;
        break;
    }

    await AppStatePersistence.save();
    debugPrint(
      'IAP success: ${purchase.productID} → ${state.purchaseType.name}',
    );
  }

  // ── Buy ─────────────────────────────────────────────────────
  // Shared purchase flow used by every buy* method below. Submits the
  // request, then WAITS for _onPurchaseUpdate to actually resolve it
  // (success / canceled / error) instead of returning as soon as the
  // App Store sheet is requested. That's the fix for buttons appearing
  // to "do nothing" when a user backs out of the purchase sheet — the
  // caller now genuinely knows what happened.
  //
  // isConsumable determines which StoreKit call gets used —
  // buyNonConsumable() for one-time-forever products (seven day,
  // fourteen day, unlock, upgrade — all still non-consumable, matches
  // how they were purchased before) vs buyConsumable() for products
  // meant to be bought repeatedly (currently just the renewal). This
  // matters beyond semantics: Apple's own StoreKit validation can
  // reject or mishandle a repeat purchase attempt on a product bought
  // through the wrong call, so it's not just a style choice.
  Future<IAPResult> _purchase(
    ProductDetails? Function() getProduct, {
    bool isConsumable = false,
  }) async {
    if (!_available) return IAPResult.storeUnavailable;

    var product = getProduct();
    if (product == null) {
      await _loadProducts();
      product = getProduct();
      if (product == null) return IAPResult.productNotFound;
    }

    final completer = Completer<IAPResult>();
    _pendingPurchases[product.id] = completer;

    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      if (isConsumable) {
        await _iap.buyConsumable(purchaseParam: purchaseParam);
      } else {
        await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      }
    } catch (e) {
      debugPrint('IAP buy error: $e');
      _pendingPurchases.remove(product.id);
      return IAPResult.error;
    }

    return completer.future.timeout(
      _purchaseTimeout,
      onTimeout: () {
        _pendingPurchases.remove(product!.id);
        return IAPResult.timeout;
      },
    );
  }

  Future<IAPResult> buySevenDay() => _purchase(() => _sevenDayProduct);

  Future<IAPResult> buyFourteenDay() => _purchase(() => _fourteenDayProduct);

  Future<IAPResult> buyUnlockApp() => _purchase(() => _unlockProduct);

  Future<IAPResult> buyUpgrade() => _purchase(() => _upgradeProduct);

  Future<IAPResult> buyRenewal() =>
      _purchase(() => _renewalProduct, isConsumable: true);

  // ── Restore ─────────────────────────────────────────────────
  // NOTE: restorePurchases() only restores non-consumables (Apple
  // doesn't track consumable purchase history for restore) — the
  // renewal product being consumable means a reinstall/new-device
  // user will NOT get their renewal back via Restore Purchases, only
  // their original sevenDay/fourteenDay/unlock/upgrade purchase.
  // That matches how a consumable extension is expected to behave
  // (it's spent, not owned), but worth knowing if support questions
  // come up about "I renewed and it didn't restore."
  Future<void> restorePurchases() async {
    if (!_available) return;
    await _iap.restorePurchases();
  }

  // ── Price strings ────────────────────────────────────────────
  String get sevenDayPrice => _sevenDayProduct?.price ?? '\$4.99';
  String get fourteenDayPrice => _fourteenDayProduct?.price ?? '\$8.99';
  String get unlockPrice => _unlockProduct?.price ?? '\$9.99';
  String get upgradePrice => _upgradeProduct?.price ?? '\$4.99';
  String get renewalPrice => _renewalProduct?.price ?? '\$2.99';
}

// ── Result enum ──────────────────────────────────────────────
// NOTE: this replaces the old enum, which had `initiated` — meaning
// "request submitted," not "purchase resolved." Every buy* call site
// must be updated: `success` now means the purchase actually completed;
// there is no longer a value that means "we don't know yet."
enum IAPResult {
  success,
  canceled,
  storeUnavailable,
  productNotFound,
  timeout,
  error,
}

extension IAPErrorMessage on IAPResult {
  String? get userMessage {
    switch (this) {
      case IAPResult.success:
        return null;
      case IAPResult.canceled:
        return null; // user intentionally backed out — no error to show
      case IAPResult.storeUnavailable:
        return 'The App Store is not available right now. Please try again later.';
      case IAPResult.productNotFound:
        return 'Purchase could not be loaded. Please check your connection and try again.';
      case IAPResult.timeout:
        return 'The purchase is taking longer than expected. Check your connection and try again — if you were charged, use Restore Purchases.';
      case IAPResult.error:
        return 'Something went wrong. Please try again.';
    }
  }
}
