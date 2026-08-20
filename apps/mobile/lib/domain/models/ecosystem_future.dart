/// Future ecosystem revenue hooks — **architecture only**.
///
/// Do not implement payments, claiming flows, or marketplaces here without
/// separate product authorization. These types exist so gym discovery and
/// plan catalogs can extend without a rewrite.
library;

/// Placeholder for a gym-claimed / verified profile (future).
class GymBusinessProfileDraft {
  const GymBusinessProfileDraft({
    required this.placeId,
    this.verified = false,
    this.partner = false,
    this.promoted = false,
    this.offerLabels = const [],
  });

  final String placeId;
  final bool verified;
  final bool partner;

  /// If true in a future release, UI must label sponsored placement clearly.
  final bool promoted;
  final List<String> offerLabels;
}

/// Placeholder for trainer-authored programs (future marketplace).
class TrainerProgramListingDraft {
  const TrainerProgramListingDraft({
    required this.id,
    required this.trainerDisplayName,
    required this.title,
    this.platformFeeBps = 0,
  });

  final String id;
  final String trainerDisplayName;
  final String title;

  /// Basis points reserved for a future platform fee — not charged today.
  final int platformFeeBps;
}

/// Three intended revenue engines (documentation for implementers).
abstract final class VytalRevenueEngines {
  static const software = 'software'; // Vytal Pro
  static const hardware = 'hardware'; // Vytal wearable
  static const fitnessEcosystem = 'fitness_ecosystem'; // gyms / trainers / partners
}
