import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Points at the Go/Gin backend from API.md.
class ApiConfig {
  static String get baseUrl {
    // Android emulators can't reach the host machine via "localhost" - they
    // need the special 10.0.2.2 alias instead. iOS simulators, desktop and
    // web all run on the host itself, so plain localhost works there.
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
  }
}
