/// Where a health value came from. Never present manual/demo as wearable.
enum DataProvenance {
  /// Measured by a paired wearable / SDK.
  wearable,

  /// Entered by the user.
  manual,

  /// Computed by Vytal from other inputs.
  derived,

  /// Explicitly marked development/demo mode only.
  demo,
}

extension DataProvenanceX on DataProvenance {
  String get label => switch (this) {
        DataProvenance.wearable => 'Wearable',
        DataProvenance.manual => 'Manual',
        DataProvenance.derived => 'Calculated',
        DataProvenance.demo => 'Demo',
      };

  bool get isProductionSafe => this != DataProvenance.demo;
}
