import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'app.dart';
import 'features/update/app_version_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Dark status bar text/icons on our light screens (iOS reads statusBarBrightness, Android reads statusBarIconBrightness).
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  // The installed version, used by the forced-update check and sent to the API.
  try {
    kAppVersion = (await PackageInfo.fromPlatform()).version;
  } catch (_) {
    // keeps "0.0.0"; the server then treats the app as unknown and the check is skipped on failure
  }

  try {
    // On Android this reads android/app/google-services.json.
    await Firebase.initializeApp();
  } catch (e) {
    // The app still opens, but push notifications will not work.
    debugPrint('Firebase init failed: $e');
  }

  runApp(const ProviderScope(child: SynsymaApp()));
}