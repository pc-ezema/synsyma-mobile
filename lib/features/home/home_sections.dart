import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../booking/booking_models.dart';
import '../booking/booking_widgets.dart';
import '../catalog/category_icons.dart';
import 'home_repository.dart';

/// The Home tab's extra blocks. Every block hides itself when it has nothing to show,
/// so a quiet account sees a clean screen and a busy one sees what matters.

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.onSeeAll});
  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black))),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(foregroundColor: AppColors.blueDark, padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: const Size(0, 30), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: const Text('See all', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
        ]),
      );
}

// ---------------------------------------------------------------- action strip

/// Up to three things waiting on the customer. Tapping opens that booking.
class ActionStrip extends ConsumerWidget {
  const ActionStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(homeSummaryProvider).value;
    if (s == null || s.actions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(children: [
        for (final a in s.actions) Padding(padding: const EdgeInsets.only(bottom: 10), child: _ActionCard(action: a)),
      ]),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action});
  final HomeAction action;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color fg, Color bg, Color border) = switch (action.type) {
      'rate' => (Icons.star_rounded, const Color(0xFFB7791F), const Color(0xFFFFF6E5), const Color(0xFFFBE3B0)),
      'pay' => (Icons.credit_card_rounded, AppColors.blueDark, const Color(0xFFEEF4FF), const Color(0xFFCFE0FF)),
      _ => (Icons.request_quote_outlined, AppColors.blueDark, const Color(0xFFEEF4FF), const Color(0xFFCFE0FF)),
    };
    return Semantics(
      button: true,
      label: '${action.title}. ${action.subtitle}',
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/bookings/${action.bookingId}'),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
            child: Row(children: [
              Container(width: 38, height: 38, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(icon, size: 21, color: fg)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(action.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black)),
                  const SizedBox(height: 2),
                  Text(action.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Color(0xFF4A4E5A))),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: fg),
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- next job

class NextJobCard extends ConsumerWidget {
  const NextJobCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = ref.watch(homeSummaryProvider).value?.nextJob;
    if (b == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionHeader('Your next job'),
        Semantics(
          button: true,
          label: 'Open ${b.title}',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push('/bookings/${b.id}'),
            child: GlassCard(
              padding: EdgeInsets.zero,
              child: IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  BookingThumb(url: b.imageUrl, width: 88),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black)),
                        const SizedBox(height: 5),
                        Row(children: [
                          const Icon(Icons.event_rounded, size: 15, color: Color(0xFF6B7280)),
                          const SizedBox(width: 5),
                          Expanded(child: Text('${formatDay(b.startsAt)} · ${formatTime(b.startsAt)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Color(0xFF4A4E5A)))),
                        ]),
                        const SizedBox(height: 3),
                        Row(children: [
                          const Icon(Icons.person_outline_rounded, size: 15, color: Color(0xFF6B7280)),
                          const SizedBox(width: 5),
                          Expanded(child: Text(b.contractorName ?? 'Contractor not assigned yet', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)))),
                        ]),
                        const SizedBox(height: 8),
                        StatusChip(b.status),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- service rows

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.name, required this.caption, required this.onTap, this.imageUrl, this.iconKey = ''});
  final String name;
  final String caption;
  final String? imageUrl;
  final String iconKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget placeholder() => Container(
          width: double.infinity,
          color: const Color(0xFFE6F0FE),
          alignment: Alignment.center,
          child: Icon(categoryIcon(null, fallbackName: iconKey), size: 32, color: AppColors.blueDark),
        );
    return Semantics(
      button: true,
      label: '$name, $caption',
      child: SizedBox(
        width: 144,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                height: 92,
                width: double.infinity,
                child: imageUrl != null ? Image.network(imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder()) : placeholder(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(height: 32, child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.25, color: AppColors.navy))),
                  const SizedBox(height: 4),
                  Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.blueDark)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 168,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: children.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) => children[i],
        ),
      );
}

/// Most booked services. Hidden if the catalog is empty or offline.
class MostBookedRow extends ConsumerWidget {
  const MostBookedRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(popularServicesProvider);
    final list = async.value ?? const [];
    if (list.isEmpty) {
      if (!async.isLoading) return const SizedBox.shrink();
      return const Padding(padding: EdgeInsets.only(bottom: 22), child: SizedBox(height: 168, child: Center(child: CircularProgressIndicator(strokeWidth: 2.5))));
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionHeader('Most Booked', onSeeAll: () => context.push('/categories')),
        _Row(children: [
          for (final s in list) _ServiceTile(name: s.name, caption: s.fromLabel, imageUrl: s.imageUrl, iconKey: s.categorySlug, onTap: () => context.push('/service/${s.id}')),
        ]),
      ]),
    );
  }
}

/// Services they have had done before, one tap to book again. Hidden until they have one.
class BookAgainRow extends ConsumerWidget {
  const BookAgainRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(homeSummaryProvider).value?.bookAgain ?? const <BookAgainItem>[];
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionHeader('Book again'),
        _Row(children: [
          for (final i in items) _ServiceTile(name: i.name, caption: 'Book again', imageUrl: i.imageUrl, iconKey: i.categoryName ?? '', onTap: () => context.push('/service/${i.serviceId}')),
        ]),
      ]),
    );
  }
}

// ---------------------------------------------------------------- how it works

/// For new customers only. Gone once they have made a booking.
class HowItWorks extends ConsumerWidget {
  const HowItWorks({super.key});

  static const _steps = [
    ('Choose a service', 'Browse the categories and pick the job you need done.'),
    ('Book and pay', 'Choose a date and time, then pay securely in the app.'),
    ('We send a pro', 'We assign a contractor and keep you updated here.'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(homeSummaryProvider).value;
    if (s == null || s.hasBookings) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionHeader('How it works'),
        GlassCard(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Column(children: [
            for (var i = 0; i < _steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: Color(0xFFE6F0FE), shape: BoxShape.circle),
                    child: Text('${i + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.blueDark)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_steps[i].$1, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black)),
                      const SizedBox(height: 2),
                      Text(_steps[i].$2, style: const TextStyle(fontSize: 12.5, height: 1.4, color: Color(0xFF6B7280))),
                    ]),
                  ),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}