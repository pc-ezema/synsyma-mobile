import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/push/push_service.dart';

const kTextBoost = 1.14;

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
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        // Keep the phone's own font setting, add the boost, cap it so layouts don't break.
        final scale = (mq.textScaler.scale(1) * kTextBoost).clamp(kTextBoost, 1.4);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        );
      },
    );
  }
}