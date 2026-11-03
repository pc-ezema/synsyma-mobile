import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/push/push_service.dart';

class SynsymaApp extends ConsumerStatefulWidget {
  const SynsymaApp({super.key});

  @override
  ConsumerState<SynsymaApp> createState() => _SynsymaAppState();
}

class _SynsymaAppState extends ConsumerState<SynsymaApp> {
  @override
  void initState() {
    super.initState();
    unawaited(ref.read(pushServiceProvider).init());
  }

  @override
  Widget build(BuildContext context) {
    // Register this phone for push every time someone signs in (including app restarts).
    ref.listen(authProvider.select((s) => s.status), (previous, next) {
      if (next == AuthStatus.signedIn) {
        unawaited(ref.read(pushServiceProvider).registerDevice());
      }
    });

    return MaterialApp.router(
      title: 'Synsyma',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      scaffoldMessengerKey: rootMessengerKey,
      routerConfig: ref.watch(routerProvider),
    );
  }
}