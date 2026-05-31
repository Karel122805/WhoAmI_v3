import 'package:flutter/foundation.dart';

import 'package:whoami_app/src/core/accessibility/accessibility_service.dart';
import 'accessibility_settings.dart';

class AccessibilityController extends ChangeNotifier {
  final AccessibilityService _service;

  AccessibilitySettings _settings = AccessibilitySettings.defaults();
  bool _loading = true;

  AccessibilityController(this._service);

  AccessibilitySettings get settings => _settings;
  bool get loading => _loading;

  Future<void> init() async {
    _loading = true;
    notifyListeners();

    _settings = await _service.loadForCurrentUser();

    _loading = false;
    notifyListeners();
  }

  Future<void> setTextSizeLevel(int level) async {
    _settings = _settings.copyWith(textSizeLevel: level);
    notifyListeners(); // ✅ aplica inmediato
    await _service.saveForCurrentUser(_settings); // ✅ guarda por usuario
  }

  Future<void> setDarkMode(bool value) async {
    _settings = _settings.copyWith(darkMode: value);
    notifyListeners(); // ✅ aplica inmediato
    await _service.saveForCurrentUser(_settings); // ✅ guarda por usuario
  }

  Future<void> setSimplified(bool value) async {
    _settings = _settings.copyWith(simplified: value);
    notifyListeners(); // ✅ aplica inmediato
    await _service.saveForCurrentUser(_settings); // ✅ guarda por usuario
  }
}





