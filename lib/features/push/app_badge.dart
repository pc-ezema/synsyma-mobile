import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_controller.dart';
import '../chat/chat_controller.dart';
import '../chat/chat_unread.dart';
import '../notifications/notifications.dart';

/// Keeps the number on the app icon equal to what is unread: notifications plus support replies.
/// Watch it once from the signed-in home screen:  ref.watch(appBadgeProvider);
final appBadgeProvider = Provider<void>((ref) {
  // When the app comes back to the front, refresh both numbers so the icon is right straight away.
  final observer = _ResumeObserver(() {
    ref.invalidate(unreadNotificationsProvider);
    ref.invalidate(chatSummaryProvider);
  });
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));

  if (ref.watch(authProvider).status != AuthStatus.signedIn) {
    setAppBadge(0);
    return;
  }
  final notifications = ref.watch(unreadNotificationsProvider).value ?? 0;
  final chat = ref.watch(chatUnreadProvider);
  setAppBadge(notifications + chat);
});

int _last = -1;

/// Sets the number on the app icon. Safe to call on any platform: it does nothing where badges are not supported.
Future<void> setAppBadge(int count) async {
  final n = count < 0 ? 0 : count;
  if (n == _last) return;
  _last = n;
  try {
    if (await AppBadgePlus.isSupported()) {
      await AppBadgePlus.updateBadge(n);
    }
  } catch (_) {
    // a badge is never worth breaking the app for
  }
}

/// Call on sign-out so the next person does not see the old number.
Future<void> clearAppBadge() => setAppBadge(0);

class _ResumeObserver extends WidgetsBindingObserver {
  _ResumeObserver(this.onResume);
  final VoidCallback onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}