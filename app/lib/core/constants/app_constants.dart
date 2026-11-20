import 'package:flutter/foundation.dart';

abstract class AppConstants {
  static const jwtKey = 'khatadost_jwt';

  /// Address of the Go backend.
  ///
  /// Set it explicitly with
  /// `flutter run --dart-define=API_BASE_URL=http://<host>:8080`
  /// (needed on a real phone: use your computer's Wi-Fi IP address).
  /// Without it, the app uses the simulator default:
  /// - Android emulator: `http://10.0.2.2:8080`, the emulator's alias for
  ///   the computer it runs on (`localhost` there means the emulator itself).
  /// - iOS simulator (and anything else): `http://localhost:8080`, because
  ///   the simulator shares the Mac's network.
  static const _baseUrlOverride = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_baseUrlOverride.isNotEmpty) return _baseUrlOverride;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  static const routeSplash    = '/';
  static const routeWelcome   = '/welcome';
  static const routeLogin     = '/login';
  static const routeRegister  = '/register';
  static const routeDashboard = '/home/dashboard';
}
