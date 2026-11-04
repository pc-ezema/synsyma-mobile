import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'chat_controller.dart';

/// Unread messages from support, for the badge on the Chat tab.
///
/// It reads the same summary the Chat tab list uses, and re-fetches it every 30 seconds
/// while the app is open. Pushes and returning from the chat refresh it straight away
/// (see push_service.dart and chat_tab.dart).
final chatUnreadProvider = Provider<int>((ref) {
  final timer = Timer.periodic(const Duration(seconds: 30), (_) => ref.invalidate(chatSummaryProvider));
  ref.onDispose(timer.cancel);

  // .value keeps the last known number while a refresh is loading, so the badge never flickers to 0.
  return ref.watch(chatSummaryProvider).value?.unread ?? 0;
});