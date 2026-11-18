import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';

// Extra scrolling sections for the Home tab. They need no data from the server, so they never
// break or hide the existing blocks. Taps open the existing /categories screen.

const _siteBase = 'https://www.synsyma.com';

/// Card heights grow a little with the app's text boost so nothing overflows.
double _scaled(BuildContext context, double h) {
  final s = MediaQuery.textScalerOf(context).scale(1.0);
  return h * s.clamp(1.0, 1.5);
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black)),
      );
}

// ---------------------------------------------------------------- What's on the to-do list?

class TodoBundles extends StatelessWidget {
  const TodoBundles({super.key});

  static const _items = [
    ('Backyard upgrade', 'Lawn, fences, decks', Icons.yard_rounded, [Color(0xFF1F7A4D), Color(0xFF3FB27F)]),
    ('Emergency repairs', 'Plumbing, electrical', Icons.build_circle_rounded, [Color(0xFFB4452C), Color(0xFFE5795B)]),
    ('Home refresh', 'Painting, deep clean', Icons.format_paint_rounded, [Color(0xFF3B4FA8), Color(0xFF6C82E0)]),
    ('Seasonal prep', 'Gutters, heating, snow', Icons.ac_unit_rounded, [Color(0xFF0F6D8C), Color(0xFF3FB4D6)]),
    ('Moving day', 'Moving, junk removal', Icons.local_shipping_rounded, [Color(0xFF6A3FA0), Color(0xFF9B6BD6)]),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        const _Title("What's on the to-do list?"),
        SizedBox(
          height: _scaled(context, 150),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final it = _items[i];
              return Semantics(
                button: true,
                label: it.$1,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.push('/categories'),
                  child: Ink(
                    width: 150,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: it.$4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(it.$3, size: 30, color: Colors.white),
                        const Spacer(),
                        Text(it.$1,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2)),
                        const SizedBox(height: 4),
                        Text(it.$2,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Color(0xE6FFFFFF), height: 1.25)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 22),
      ],
    );
  }
}

// ---------------------------------------------------------------- Why Synsyma

class WhySynsyma extends StatelessWidget {
  const WhySynsyma({super.key});

  static const _items = [
    (Icons.verified_user_rounded, 'Verified pros', 'Every pro is ID-checked and approved before they work for you.'),
    (Icons.fact_check_rounded, 'Background checked', 'We run a background check before a pro is approved.'),
    (Icons.lock_rounded, 'Secure payment', 'Pay safely by card. Nothing is charged without your booking.'),
    (Icons.event_repeat_rounded, 'Flexible plans', 'Free cancellation when your job is more than 24 hours away.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Title('Why Synsyma'),
        SizedBox(
          height: _scaled(context, 148),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final it = _items[i];
              return Container(
                width: 210,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.fieldBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(color: AppColors.authBg, borderRadius: BorderRadius.circular(12)),
                      child: Icon(it.$1, size: 22, color: AppColors.blueDark),
                    ),
                    const SizedBox(height: 10),
                    Text(it.$2, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.black)),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(it.$3,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, height: 1.35, color: Color(0xFF5B6275))),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 22),
      ],
    );
  }
}

// ---------------------------------------------------------------- Urgent job banner

class UrgentCard extends StatelessWidget {
  const UrgentCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.navy, Color(0xFF1B3F8F)]),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Something urgent?',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 6),
                  const Text('Pick a service and book the next available pro.',
                      style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xDDFFFFFF))),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () => context.push('/categories'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.navy,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                    child: const Text('Find a service', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.bolt_rounded, size: 64, color: Color(0x33FFFFFF)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Common questions + links

class CommonQuestions extends StatelessWidget {
  const CommonQuestions({super.key});

  static const _faq = [
    ('How do you choose a contractor?',
        'Every contractor is verified (ID and background check) before they are approved. We assign the right pro to your booking and you can see who is coming.'),
    ('Can I cancel or reschedule?',
        'Cancelling is free when no contractor is assigned yet, or when your job is more than 24 hours away. Closer to the time, the cancellation terms apply. Details are in the Terms.'),
    ('How do I pay?',
        'Securely by card when you book. Some jobs need a quote first. Once you accept the quote, you pay by card.'),
    ('What if something goes wrong?',
        'Message support from the Chat tab and we will help. Include your booking so we can find it quickly.'),
  ];

  Future<void> _open(BuildContext context, String page) async {
    final ok = await launchUrl(Uri.parse('$_siteBase/$page'), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't open the page.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Title('Common questions'),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.fieldBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Column(
              children: [
                for (var i = 0; i < _faq.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.fieldBorder),
                  ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    title: Text(_faq[i].$1, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black)),
                    children: [Text(_faq[i].$2, style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF5B6275)))],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
      ],
    );
  }
}

