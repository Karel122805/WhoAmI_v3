class AccessibilitySettings {
  final int textSizeLevel; // 0=normal, 1=mediano, 2=grande
  final bool darkMode;
  final bool simplified;

  const AccessibilitySettings({
    required this.textSizeLevel,
    required this.darkMode,
    required this.simplified,
  });

  factory AccessibilitySettings.defaults() {
    return const AccessibilitySettings(
      textSizeLevel: 0,
      darkMode: false,
      simplified: false,
    );
  }

  double get textScale {
    switch (textSizeLevel) {
      case 1:
        return 1.15;
      case 2:
        return 1.30;
      case 0:
      default:
        return 1.0;
    }
  }

  AccessibilitySettings copyWith({
    int? textSizeLevel,
    bool? darkMode,
    bool? simplified,
  }) {
    return AccessibilitySettings(
      textSizeLevel: textSizeLevel ?? this.textSizeLevel,
      darkMode: darkMode ?? this.darkMode,
      simplified: simplified ?? this.simplified,
    );
  }

  Map<String, dynamic> toMap() => {
        'a11y_textSizeLevel': textSizeLevel,
        'a11y_darkMode': darkMode,
        'a11y_simplified': simplified,
      };

  factory AccessibilitySettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) return AccessibilitySettings.defaults();
    return AccessibilitySettings(
      textSizeLevel: (map['a11y_textSizeLevel'] ?? 0) as int,
      darkMode: (map['a11y_darkMode'] ?? false) as bool,
      simplified: (map['a11y_simplified'] ?? false) as bool,
    );
  }
}





