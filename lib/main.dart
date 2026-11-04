import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // On Android this reads android/app/google-services.json.
    await Firebase.initializeApp();
  } catch (e) {
    // The app still opens, but push notifications will not work.
    debugPrint('Firebase init failed: $e');
  }

  runApp(const ProviderScope(child: SynsymaApp()));
}