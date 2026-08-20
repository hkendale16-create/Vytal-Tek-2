/// Fitness ecosystem layer — gym partners + trainer programs.
///
/// Payments / platform fees are **not charged in this client**. Listings can be
/// browsed, claimed (request), and saved locally. Sponsored placements must be
/// labeled when [GymBusinessProfile.promoted] is true.
library;

import 'package:uuid/uuid.dart';

/// Claimed / partner gym profile attached to a [GymPlace.id].
class GymBusinessProfile {
  const GymBusinessProfile({
    required this.placeId,
    required this.businessName,
    this.contactEmail,
    this.verified = false,
    this.partner = false,
    this.promoted = false,
    this.offerLabels = const [],
    this.claimStatus = GymClaimStatus.none,
    this.requestedAt,
  });

  final String placeId;
  final String businessName;
  final String? contactEmail;
  final bool verified;
  final bool partner;

  /// Sponsored placement — UI must show a clear Sponsored label.
  final bool promoted;
  final List<String> offerLabels;
  final GymClaimStatus claimStatus;
  final DateTime? requestedAt;

  GymBusinessProfile copyWith({
    String? businessName,
    String? contactEmail,
    bool? verified,
    bool? partner,
    bool? promoted,
    List<String>? offerLabels,
    GymClaimStatus? claimStatus,
    DateTime? requestedAt,
  }) {
    return GymBusinessProfile(
      placeId: placeId,
      businessName: businessName ?? this.businessName,
      contactEmail: contactEmail ?? this.contactEmail,
      verified: verified ?? this.verified,
      partner: partner ?? this.partner,
      promoted: promoted ?? this.promoted,
      offerLabels: offerLabels ?? this.offerLabels,
      claimStatus: claimStatus ?? this.claimStatus,
      requestedAt: requestedAt ?? this.requestedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'placeId': placeId,
        'businessName': businessName,
        'contactEmail': contactEmail,
        'verified': verified,
        'partner': partner,
        'promoted': promoted,
        'offerLabels': offerLabels,
        'claimStatus': claimStatus.name,
        'requestedAt': requestedAt?.toIso8601String(),
      };

  factory GymBusinessProfile.fromJson(Map<String, dynamic> json) =>
      GymBusinessProfile(
        placeId: json['placeId'] as String? ?? '',
        businessName: json['businessName'] as String? ?? 'Gym',
        contactEmail: json['contactEmail'] as String?,
        verified: json['verified'] as bool? ?? false,
        partner: json['partner'] as bool? ?? false,
        promoted: json['promoted'] as bool? ?? false,
        offerLabels:
            (json['offerLabels'] as List?)?.cast<String>() ?? const [],
        claimStatus: GymClaimStatusX.fromJson(json['claimStatus'] as String?),
        requestedAt: DateTime.tryParse(json['requestedAt'] as String? ?? ''),
      );
}

enum GymClaimStatus { none, pending, approved, rejected }

extension GymClaimStatusX on GymClaimStatus {
  String get label => switch (this) {
        GymClaimStatus.none => 'Unclaimed',
        GymClaimStatus.pending => 'Claim pending',
        GymClaimStatus.approved => 'Claimed',
        GymClaimStatus.rejected => 'Claim rejected',
      };

  static GymClaimStatus fromJson(String? raw) => GymClaimStatus.values
      .firstWhere((e) => e.name == raw, orElse: () => GymClaimStatus.none);
}

/// Trainer-authored program listing (marketplace browse).
class TrainerProgramListing {
  const TrainerProgramListing({
    required this.id,
    required this.trainerDisplayName,
    required this.title,
    required this.tagline,
    this.weeks = 4,
    this.daysPerWeek = '3–4',
    this.focusAreas = const [],
    this.platformFeeBps = 1000,
    this.priceLabel = 'Free preview',
    this.advanced = false,
  });

  final String id;
  final String trainerDisplayName;
  final String title;
  final String tagline;
  final int weeks;
  final String daysPerWeek;
  final List<String> focusAreas;

  /// Reserved platform fee (basis points) — **not charged** in this build.
  final int platformFeeBps;
  final String priceLabel;
  final bool advanced;

  String get feeNote =>
      'Platform fee reserved at ${(platformFeeBps / 100).toStringAsFixed(0)}% — not charged yet.';

  Map<String, dynamic> toJson() => {
        'id': id,
        'trainerDisplayName': trainerDisplayName,
        'title': title,
        'tagline': tagline,
        'weeks': weeks,
        'daysPerWeek': daysPerWeek,
        'focusAreas': focusAreas,
        'platformFeeBps': platformFeeBps,
        'priceLabel': priceLabel,
        'advanced': advanced,
      };

  factory TrainerProgramListing.fromJson(Map<String, dynamic> json) =>
      TrainerProgramListing(
        id: json['id'] as String? ?? const Uuid().v4(),
        trainerDisplayName: json['trainerDisplayName'] as String? ?? 'Trainer',
        title: json['title'] as String? ?? 'Program',
        tagline: json['tagline'] as String? ?? '',
        weeks: json['weeks'] as int? ?? 4,
        daysPerWeek: json['daysPerWeek'] as String? ?? '3',
        focusAreas: (json['focusAreas'] as List?)?.cast<String>() ?? const [],
        platformFeeBps: json['platformFeeBps'] as int? ?? 1000,
        priceLabel: json['priceLabel'] as String? ?? 'Free preview',
        advanced: json['advanced'] as bool? ?? false,
      );
}

/// Seeded marketplace catalog — local browse without live payments.
abstract final class TrainerMarketplaceCatalog {
  static List<TrainerProgramListing> get featured => const [
        TrainerProgramListing(
          id: 'trainer-maya-strength',
          trainerDisplayName: 'Maya Chen',
          title: 'Foundations Strength',
          tagline: 'Barbell patterns for busy schedules',
          weeks: 6,
          daysPerWeek: '3',
          focusAreas: ['Strength', 'Full body'],
          priceLabel: 'Free preview',
        ),
        TrainerProgramListing(
          id: 'trainer-jordan-engine',
          trainerDisplayName: 'Jordan Blake',
          title: 'Engine Builder',
          tagline: 'Conditioning without outcome guarantees',
          weeks: 5,
          daysPerWeek: '4',
          focusAreas: ['Conditioning', 'Cardio'],
          priceLabel: 'Free preview',
        ),
        TrainerProgramListing(
          id: 'trainer-aria-cali',
          trainerDisplayName: 'Aria Okonkwo',
          title: 'Calisthenics Path',
          tagline: 'Pull · Push · Core progressions',
          weeks: 8,
          daysPerWeek: '3–4',
          focusAreas: ['Calisthenics', 'Mobility'],
          advanced: true,
          priceLabel: 'Pro preview',
        ),
      ];
}

abstract final class VytalRevenueEngines {
  static const software = 'software';
  static const hardware = 'hardware';
  static const fitnessEcosystem = 'fitness_ecosystem';
}

/// @Deprecated Keep old names for any leftover imports.
@Deprecated('Use GymBusinessProfile')
typedef GymBusinessProfileDraft = GymBusinessProfile;

@Deprecated('Use TrainerProgramListing')
typedef TrainerProgramListingDraft = TrainerProgramListing;
