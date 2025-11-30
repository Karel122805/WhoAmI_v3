import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricAuthService {
  BiometricAuthService._();
  static final instance = BiometricAuthService._();

  final _auth = LocalAuthentication();
  final _storage = const FlutterSecureStorage();

  static const _kBiometricEnabledKey = 'biometric_enabled';
  static const _kLockEnabledKey = 'app_lock_enabled';

  // ===== Verifica compatibilidad del dispositivo =====
  Future<bool> isDeviceSupported() => _auth.isDeviceSupported();

  Future<bool> canCheckBiometrics() async {
    try {
      return (await _auth.canCheckBiometrics) || (await isDeviceSupported());
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasBiometricsEnrolled() async {
    try {
      final types = await _auth.getAvailableBiometrics();
      return types.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ===== Autenticación =====
  Future<bool> authenticate({
    String reason = 'Confirma tu identidad',
  }) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
      );
      return ok;
    } catch (e) {
      return false;
    }
  }

  // ===== Detiene cualquier autenticación activa =====
  Future<void> stop() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {}
  }

  // ===== Preferencias seguras =====
  Future<void> setBiometricEnabled(bool value) async =>
      _storage.write(key: _kBiometricEnabledKey, value: value.toString());

  Future<bool> getBiometricEnabled() async =>
      (await _storage.read(key: _kBiometricEnabledKey)) == 'true';

  Future<void> setAppLockEnabled(bool value) async =>
      _storage.write(key: _kLockEnabledKey, value: value.toString());

  Future<bool> getAppLockEnabled() async =>
      (await _storage.read(key: _kLockEnabledKey)) == 'true';

  Future<bool> shouldLockOnLaunch() async {
    final lockOn = await getAppLockEnabled();
    final canBio = await canCheckBiometrics();
    return lockOn && canBio;
  }
}
