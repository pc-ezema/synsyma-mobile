import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sub_page.dart';
import '../home/main_tab.dart';
import 'booking_models.dart';
import 'booking_repository.dart';
import 'booking_widgets.dart';

/// The body of the Bookings tab: Upcoming, Canceled and Completed.
class BookingsTab extends ConsumerStatefulWidget {
  const BookingsTab({super.key});

  @override
  ConsumerState<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends ConsumerState<BookingsTab> {
  static const _scopes = ['upcoming', 'cancelled', 'completed'];
  String _scope = 'upcoming';

  String _label(String scope, int upcoming) => switch (scope) {
        'upcoming' => upcoming > 0 ? 'Upcoming ($upcoming)' : 'Upcoming',
        'cancelled' => 'Canceled',
        _ => 'Completed',
      };

  String _emptyText() => switch (_scope) {
        'upcoming' => 'No upcoming bookings.',
        'cancelled' => 'No canceled bookings.',
        _ => 'No completed bookings yet.',
      };

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(bookingsProvider(_scope));
    final page = async.value;
    final list = page?.items ?? const <Booking>[];
    // Any loaded tab carries the counts, so the Upcoming count stays visible while you look at another tab.
    final upcomingCount = page?.upcoming ?? ref.watch(bookingsProvider('upcoming')).value?.upcoming ?? 0;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Identical to the Chat and Profile tab headers.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(
            children: [
              const Text('Bookings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black)),
              const Spacer(),
              IconButton(
                tooltip: 'Notifications',
                onPressed: () => showToast(context, 'No notifications yet.'),
                icon: const Icon(Icons.notifications_rounded, size: 26, color: Color(0xFF4B5060)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white)),
            child: Row(children: [
              for (final s in _scopes)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _scope = s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: _scope == s ? AppColors.blueDark : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        _label(s, upcomingCount),
                        style: TextStyle(fontSize: 14, fontWeight: _scope == s ? FontWeight.w700 : FontWeight.w500, color: _scope == s ? Colors.white : const Color(0xFF6B7280)),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(bookingsProvider(_scope));
              await ref.read(bookingsProvider(_scope).future);
            },
            child: async.isLoading && page == null
                ? ListView(children: const [SizedBox(height: 120), Center(child: CircularProgressIndicator())])
                : async.hasError && page == null
                    ? ListView(children: [
                        const SizedBox(height: 100),
                        const Center(child: Text('Could not load your bookings.', style: TextStyle(color: Color(0xFF6B7280)))),
                        const SizedBox(height: 10),
                        Center(child: OutlinedButton(onPressed: () => ref.invalidate(bookingsProvider(_scope)), child: const Text('Try again'))),
                      ])
                    : list.isEmpty
                        ? ListView(children: [
                            const SizedBox(height: 80),
                            const Center(child: Icon(Icons.event_available_outlined, size: 52, color: Color(0xFF9CA3AF))),
                            const SizedBox(height: 12),
                            Center(child: Text(_emptyText(), style: const TextStyle(fontSize: 15, color: Color(0xFF6B7280)))),
                            if (_scope == 'upcoming') ...[
                              const SizedBox(height: 16),
                              Center(
                                child: FilledButton(
                                  // The app theme gives buttons an infinite minimum width, so set our own size.
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.blueDark,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(200, 50),
                                    fixedSize: const Size(200, 50),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () => ref.read(mainTabProvider.notifier).select(0),
                                  child: const Text('Browse services', style: TextStyle(fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ])
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                            itemCount: list.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 14),
                            itemBuilder: (_, i) => _BookingCard(b: list[i], onTap: () => context.push('/bookings/${list[i].id}')),
                          ),
          ),
        ),
        ]),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.b, required this.onTap});
  final Booking b;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            BookingThumb(url: b.imageUrl, width: 108),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: CategoryPill(b.categoryName ?? 'Service')),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF6B7280)),
                  ]),
                  const SizedBox(height: 8),
                  Text(b.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black)),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF6B7280)),
                    const SizedBox(width: 4),
                    Expanded(child: Text(b.shortAddress, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)))),
                  ]),
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.schedule_rounded, size: 15, color: Color(0xFF6B7280)),
                    const SizedBox(width: 4),
                    Expanded(child: Text('${formatDay(b.startsAt)} · ${formatTime(b.startsAt)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)))),
                  ]),
                  const SizedBox(height: 10),
                  StatusChip(b.status),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}