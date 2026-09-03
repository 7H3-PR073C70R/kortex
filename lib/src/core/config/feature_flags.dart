import 'package:flutter/foundation.dart';

/// Central runtime feature flag controller for Kortex public launch.
class FeatureFlags {
  FeatureFlags._();

  static final FeatureFlags instance = FeatureFlags._();

  // 1. Launch Feature Flags with defaults
  bool _enableSocialRooms = false; // Hide live study rooms for MVP launch
  bool _enableOfflineGGUF = false; // Isolated off critical onboarding path
  bool _enableSyllabusImport = true;
  bool _enableFSRSFlashcards = true;

  bool get enableSocialRooms => _enableSocialRooms;
  bool get enableOfflineGGUF => _enableOfflineGGUF;
  bool get enableSyllabusImport => _enableSyllabusImport;
  bool get enableFSRSFlashcards => _enableFSRSFlashcards;

  /// Updates runtime feature flag overrides.
  void setOverrides({
    bool? enableSocialRooms,
    bool? enableOfflineGGUF,
    bool? enableSyllabusImport,
    bool? enableFSRSFlashcards,
  }) {
    if (enableSocialRooms != null) {
      _enableSocialRooms = enableSocialRooms;
    }
    if (enableOfflineGGUF != null) {
      _enableOfflineGGUF = enableOfflineGGUF;
    }
    if (enableSyllabusImport != null) {
      _enableSyllabusImport = enableSyllabusImport;
    }
    if (enableFSRSFlashcards != null) {
      _enableFSRSFlashcards = enableFSRSFlashcards;
    }
    debugPrint('[FeatureFlags] Updated flags: ${toMap()}');
  }

  /// Resets all flags to default MVP launch configuration.
  void resetToDefaults() {
    _enableSocialRooms = false;
    _enableOfflineGGUF = false;
    _enableSyllabusImport = true;
    _enableFSRSFlashcards = true;
  }

  /// Exports current flag states to map.
  Map<String, bool> toMap() => {
    'enableSocialRooms': _enableSocialRooms,
    'enableOfflineGGUF': _enableOfflineGGUF,
    'enableSyllabusImport': _enableSyllabusImport,
    'enableFSRSFlashcards': _enableFSRSFlashcards,
  };

  /// Ingests flag states from JSON or remote config map.
  void fromMap(Map<String, dynamic> map) {
    if (map.containsKey('enableSocialRooms') &&
        map['enableSocialRooms'] is bool) {
      _enableSocialRooms = map['enableSocialRooms'] as bool;
    }
    if (map.containsKey('enableOfflineGGUF') &&
        map['enableOfflineGGUF'] is bool) {
      _enableOfflineGGUF = map['enableOfflineGGUF'] as bool;
    }
    if (map.containsKey('enableSyllabusImport') &&
        map['enableSyllabusImport'] is bool) {
      _enableSyllabusImport = map['enableSyllabusImport'] as bool;
    }
    if (map.containsKey('enableFSRSFlashcards') &&
        map['enableFSRSFlashcards'] is bool) {
      _enableFSRSFlashcards = map['enableFSRSFlashcards'] as bool;
    }
  }
}
