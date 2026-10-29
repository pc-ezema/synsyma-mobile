import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand_background.dart';
import '../auth/auth_controller.dart';
import '../onboarding/onboarding_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    // Show the splash for at least 1.8s, and wait for the saved login check.
    await Future.wait([
      ref.read(authProvider.notifier).ready,
      Future<void>.delayed(const Duration(milliseconds: 1800)),
    ]);
    if (!mounted) return;

    if (ref.read(authProvider).status == AuthStatus.signedIn) {
      context.go('/home');
      return;
    }
    final seen = await ref.read(storageProvider).read(key: onboardingSeenKey);
    if (!mounted) return;
    context.go(seen == 'true' ? '/login' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BrandBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) => Opacity(
                    opacity: t,
                    child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
                  ),
                  child: const _LogoTile(),
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 72,
                child: Center(
                  child: CupertinoActivityIndicator(radius: 14, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoTile extends StatelessWidget {
  const _LogoTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 122,
      height: 122,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.logoTile,
        borderRadius: BorderRadius.circular(28),
      ),
      // Use your logo without its own background tile (transparent PNG).
      child: Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(
          child: Text(
            'Synsyma',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
