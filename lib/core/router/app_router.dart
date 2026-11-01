import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/new_password_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/reset_code_screen.dart';
import '../../features/auth/success_screen.dart';
import '../../features/auth/verify_email_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/main_tab.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/profile/change_password_screens.dart';
import '../../features/profile/edit_profile_screen.dart';
import '../../features/profile/terms_screen.dart';
import '../../features/splash/splash_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  // Screens only signed-out people should see.
  const guestOnly = {
    '/onboarding',
    '/login',
    '/register',
    '/verify-email',
    '/forgot-password',
    '/reset-code',
    '/new-password',
    '/verified',
    '/password-updated',
  };

  // Open to everyone, signed in or not.
  const openToAll = {'/splash', '/terms'};

  String? needEmail(GoRouterState s) =>
      (s.uri.queryParameters['email'] ?? '').isEmpty ? '/login' : null;

  int resendOf(GoRouterState s) => int.tryParse(s.uri.queryParameters['resend'] ?? '') ?? 60;

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final status = ref.read(authProvider).status;
      final loc = state.matchedLocation;

      if (status == AuthStatus.unknown) return loc == '/splash' ? null : '/splash';

      if (status == AuthStatus.signedOut) {
        return (openToAll.contains(loc) || guestOnly.contains(loc)) ? null : '/login';
      }

      return guestOnly.contains(loc) ? '/home' : null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/verify-email',
        redirect: (_, s) => needEmail(s),
        builder: (_, s) => VerifyEmailScreen(
          email: s.uri.queryParameters['email']!,
          resendIn: resendOf(s),
        ),
      ),
      GoRoute(
        path: '/verified',
        builder: (context, _) => SuccessScreen(
          title: 'Verification Successful',
          subtitle: 'Proceed to login to your dashboard',
          onContinue: () => context.go('/login'),
        ),
      ),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/reset-code',
        redirect: (_, s) => needEmail(s) == null ? null : '/forgot-password',
        builder: (_, s) => ResetCodeScreen(
          email: s.uri.queryParameters['email']!,
          resendIn: resendOf(s),
        ),
      ),
      GoRoute(
        path: '/new-password',
        redirect: (_, s) => s.extra is Map ? null : '/forgot-password',
        builder: (_, s) {
          final extra = s.extra! as Map;
          return NewPasswordScreen(
            email: extra['email'] as String,
            resetToken: extra['resetToken'] as String,
          );
        },
      ),
      GoRoute(
        path: '/password-updated',
        builder: (context, _) => SuccessScreen(
          title: 'Password Created Successful',
          subtitle: 'Proceed to login to your dashboard',
          onContinue: () => context.go('/login'),
        ),
      ),
      GoRoute(path: '/terms', builder: (_, __) => const TermsScreen()),

      // Signed-in area
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/profile/edit/:field',
        builder: (_, s) => EditProfileScreen(
          field: ProfileField.values.asNameMap()[s.pathParameters['field']] ?? ProfileField.phone,
        ),
      ),
      GoRoute(path: '/profile/password', builder: (_, __) => const PasswordEmailScreen()),
      GoRoute(
        path: '/profile/password/code',
        redirect: (_, s) => needEmail(s) == null ? null : '/profile/password',
        builder: (_, s) => PasswordCodeScreen(
          email: s.uri.queryParameters['email']!,
          resendIn: resendOf(s),
        ),
      ),
      GoRoute(
        path: '/profile/password/new',
        redirect: (_, s) => s.extra is Map ? null : '/profile/password',
        builder: (_, s) => PasswordNewScreen(changeToken: (s.extra! as Map)['changeToken'] as String),
      ),
      GoRoute(
        path: '/profile/password/done',
        builder: (context, _) => SuccessScreen(
          title: 'Password Updated Successfully',
          subtitle: 'Your new password is ready to use',
          onContinue: () {
            ref.read(mainTabProvider.notifier).select(3); // back to the Profile tab
            context.go('/home');
          },
        ),
      ),
    ],
  );
});