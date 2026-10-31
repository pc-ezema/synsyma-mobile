import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint, kReleaseMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  // Read exactly the same key the rest of the app reads.
  const apiUrl = String.fromEnvironment('API_URL', defaultValue: '⚠️_MISSING');
  const env = String.fromEnvironment('ENV', defaultValue: '⚠️_MISSING');

  debugPrint('[BOOT] ENV      = $env');
  debugPrint('[BOOT] API_URL  = $apiUrl');
  debugPrint('[BOOT] release  = $kReleaseMode');

  if (apiUrl == '⚠️_MISSING') {
    debugPrint(
      '[BOOT] ❌ API_URL was not provided. '
      'Run with --dart-define-from-file=env/dev.json '
      'or the app will fall back to a default (likely localhost).',
    );
  }

  runApp(const ProviderScope(child: SynsymaApp()));
}