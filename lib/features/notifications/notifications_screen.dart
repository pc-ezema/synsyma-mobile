import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sub_page.dart';
import '../booking/booking_repository.dart';
import 'notifications.dart';
import '../booking/booking_widgets.dart';

/// Everything we told the customer about their bookings. Route: /notifications
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final Set<String> _readHere = {}; // marked as read on this screen, so the dot goes at once

  IconData _icon(String type) => switch (type) {
        'booking_confirmed' => Icons.check_circle_outline_rounded,
        'contractor_assigned' => Icons.person_outline_rounded,
        'booking_rescheduled' => Icons.event_repeat_rounded,
        'job_started' => Icons.play_circle_outline_rounded,
        'job_completed' => Icons.task_alt_rounded,
        'booking_cancelled' => Icons.cancel_outlined,
        'refund_issued' => Icons.payments_outlined,
        'review_reminder' => Icons.star_outline_rounded,
        'quote_requested' || 'quote_ready' || 'quote_expiring' || 'quote_expired' => Icons.request_quote_outlined,
        _ => Icons.notifications_none_rounded,
      };

  bool _isBad(String type) => type == 'booking_cancelled' || type == 'quote_expired';

  String _ago(DateTime? t) {
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    if (d.inDays < 7) return '${d.inDays} ${d.inDays == 1 ? 'day' : 'days'} ago';
    return '${t.day}/${t.month}/${t.year}';
  }

  Future<void> _open(AppNotification n) async {
    final repo = ref.read(notificationsRepositoryProvider);
    if (!n.read && !_readHere.contains(n.id)) {
      setState(() => _readHere.add(n.id));
      try {
        await repo.markRead(n.id);
      } catch (_) {}
      ref.invalidate(unreadNotificationsProvider);
    }
    if (n.bookingId != null && mounted) {
      await context.push('/bookings/${n.bookingId}');
      ref.invalidate(bookingsProvider('upcoming'));
    }
  }

  Future<void> _readAll(List<AppNotification> items) async {
    try {
      await ref.read(notificationsRepositoryProvider).markAllRead();
      setState(() => _readHere.addAll(items.map((e) => e.id)));
      ref.invalidate(unreadNotificationsProvider);
    } on ApiError catch (e) {
      if (mounted) showToast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationsProvider);
    final items = async.value;

    return SubPageScaffold(
      title: 'Notifications',
      children: [
        if (items == null && async.isLoading)
          const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator()))
        else if (items == null)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Column(children: [
              const Text('Could not load your notifications.', style: TextStyle(color: Color(0xFF6B7280))),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: () => ref.invalidate(notificationsProvider), child: const Text('Try again')),
            ]),
          )
        else if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 70),
            child: Column(children: [
              Container(width: 72, height: 72, decoration: const BoxDecoration(color: Color(0xFFE6F0FE), shape: BoxShape.circle), child: const Icon(Icons.notifications_none_rounded, size: 32, color: AppColors.blueDark)),
              const SizedBox(height: 16),
              const Text('Nothing yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.black)),
              const SizedBox(height: 6),
              const Text('Updates about your bookings and quotes will show up here.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF6B7280))),
            ]),
          )
        else ...[
          if (items.any((n) => !n.read && !_readHere.contains(n.id)))
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _readAll(items),
                style: TextButton.styleFrom(foregroundColor: AppColors.blueDark),
                child: const Text('Mark all as read', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              ),
            ),
          for (final n in items) ...[
            _tile(n),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }

  Widget _tile(AppNotification n) {
    final unread = !n.read && !_readHere.contains(n.id);
    final color = _isBad(n.type) ? AppColors.danger : AppColors.blueDark;
    return Semantics(
      button: true,
      label: '${unread ? 'Unread. ' : ''}${n.title}. ${n.body}',
      child: InkWell(
        onTap: () => _open(n),
        borderRadius: BorderRadius.circular(18),
        child: GlassCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(_icon(n.type), size: 21, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(n.title, style: TextStyle(fontSize: 14.5, fontWeight: unread ? FontWeight.w700 : FontWeight.w600, color: Colors.black))),
                  if (unread) Container(width: 9, height: 9, margin: const EdgeInsets.only(left: 8), decoration: const BoxDecoration(color: AppColors.blueDark, shape: BoxShape.circle)),
                ]),
                const SizedBox(height: 3),
                Text(n.body, style: const TextStyle(fontSize: 13.5, height: 1.4, color: Color(0xFF4A4E5A))),
                const SizedBox(height: 6),
                Text(_ago(n.createdAt), style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}