import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../devices/connection/device_connection_controller.dart';
import '../domain/devices/device_connection_state.dart';
import '../domain/models/entitlements.dart';
import '../domain/models/operating_mode.dart';
import '../state/app_session_controller.dart';
import 'entitlement_service.dart';
import 'feature_access_config.dart';
import 'product_catalog.dart';
import 'subscription_controller.dart';

/// Unified product experience — Free / Pro / Device / Complete ecosystem.
///
/// Screens should prefer [MonetizationFacade.canUseFeature] and [experience]
/// over raw `SubscriptionTier` string compares.
enum VytalExperienceState {
  /// Software free defaults; no paired wearable.
  free,

  /// Time-limited Pro access (server-verified trial).
  trial,

  /// Paid software; no device paired.
  pro,

  /// Compatible device paired; Free software.
  deviceOwner,

  /// Pro (or Complete packaging) + paired device — strongest experience.
  proDevice,
}

extension VytalExperienceStateX on VytalExperienceState {
  String get id => name;

  String get label => switch (this) {
        VytalExperienceState.free => 'Vytal Free',
        VytalExperienceState.trial => 'Vytal Pro Trial',
        VytalExperienceState.pro => 'Vytal Pro',
        VytalExperienceState.deviceOwner => 'Vytal Device',
        VytalExperienceState.proDevice => 'Vytal Complete Experience',
      };

  /// One-line principle copy for UI / upgrade surfaces.
  String get principle => switch (this) {
        VytalExperienceState.free => 'Helps you train.',
        VytalExperienceState.trial ||
        VytalExperienceState.pro =>
          'Helps you train smarter.',
        VytalExperienceState.deviceOwner =>
          'Helps Vytal understand how your body responds.',
        VytalExperienceState.proDevice =>
          'Training + AI + advanced analytics + wearable personalization.',
      };

  bool get hasProSoftware =>
      this == VytalExperienceState.pro ||
      this == VytalExperienceState.trial ||
      this == VytalExperienceState.proDevice;

  bool get hasDevice =>
      this == VytalExperienceState.deviceOwner ||
      this == VytalExperienceState.proDevice;
}

/// Central monetization answers — single place for feature + experience checks.
class MonetizationFacade {
  const MonetizationFacade({
    required this.entitlements,
    required this.experience,
    required this.config,
    required this.catalog,
  });

  final EntitlementService entitlements;
  final VytalExperienceState experience;
  final FeatureAccessConfig config;
  final SubscriptionCatalog catalog;

  bool canUseFeature(String key) {
    if (!config.isFeatureEnabled(key)) return false;
    // Device-core features are never subscription-gated here.
    if (DeviceExperienceFeatures.isCoreDeviceFeature(key)) {
      return experience.hasDevice;
    }
    final required = config.requiredTierFor(key);
    if (required == null) {
      return entitlements.canUse(key);
    }
    // Free keys always pass when in freeDefaults.
    if (EntitlementSecurity.freeKeys.contains(key)) {
      return entitlements.canUse(key);
    }
    if (!experience.hasProSoftware &&
        required.contains(SubscriptionTier.pro)) {
      // Still honor verified entitlements (sandbox / server).
      return entitlements.canUse(key);
    }
    return entitlements.canUse(key);
  }

  bool get showProPreviews => !experience.hasProSoftware;

  bool get mayPromptDeviceExplore =>
      !experience.hasDevice && experience != VytalExperienceState.proDevice;

  String requiredPlanLabel(String key) => catalog.requiredPlanLabel(key);

  static VytalExperienceState resolve({
    required EntitlementSnapshot snapshot,
    required bool devicePaired,
    bool trialActive = false,
  }) {
    final proSoftware = snapshot.isSubscribed ||
        (trialActive &&
            snapshot.lifecycle.grantsAccess &&
            snapshot.tier != SubscriptionTier.free);
    // Explicit trial source: lifecycle active on free tier with paid keys
    // is not used; trial is signaled by [trialActive] from billing.
    if (devicePaired && (proSoftware || trialActive)) {
      return VytalExperienceState.proDevice;
    }
    if (devicePaired) return VytalExperienceState.deviceOwner;
    if (trialActive) return VytalExperienceState.trial;
    if (proSoftware) return VytalExperienceState.pro;
    return VytalExperienceState.free;
  }
}

final featureAccessConfigProvider =
    StateNotifierProvider<FeatureAccessConfigController, FeatureAccessConfig>(
  (ref) => FeatureAccessConfigController()..restore(),
);

final monetizationProvider = Provider<MonetizationFacade>((ref) {
  final session = ref.watch(appSessionProvider);
  final connection = ref.watch(deviceConnectionProvider);
  final config = ref.watch(featureAccessConfigProvider);
  final catalog = ref.watch(subscriptionCatalogProvider);
  final devicePaired = session.operatingMode == OperatingMode.connected ||
      session.pairedDevice != null ||
      connection.state == DeviceConnectionState.connected ||
      connection.activeDevice != null;
  final trialActive = session.entitlements.lifecycle.grantsAccess &&
      session.entitlements.verificationSource ==
          EntitlementVerificationSource.serverVerified &&
      session.entitlements.productId?.contains('trial') == true;
  final experience = MonetizationFacade.resolve(
    snapshot: session.entitlements,
    devicePaired: devicePaired,
    trialActive: trialActive,
  );
  return MonetizationFacade(
    entitlements: EntitlementService(session.entitlements),
    experience: experience,
    config: config,
    catalog: catalog,
  );
});
