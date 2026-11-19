import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

// Extra scrolling sections for the Home tab. They need no data from the server, so they never
// break or hide the existing blocks. Taps open the existing /categories screen.
//
// Motion: each block fades and slides in the first time it scrolls into view (once), cards press in
// slightly when touched, and the bolt on the urgent card pulses gently. All of it is skipped when the
// phone's "reduce motion" setting is on. To switch the entrance animation off, change Reveal.build to
// return widget.builder(context, const AlwaysStoppedAnimation(1.0)).

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

// ---------------------------------------------------------------- motion helpers

/// Runs once, the first time this block is near the bottom of the screen while scrolling.
/// [builder] gets a 0 to 1 animation to drive its own pieces (see [_fadeUp]).
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.builder, this.duration = const Duration(milliseconds: 800)});

  final Widget Function(BuildContext context, Animation<double> t) builder;
  final Duration duration;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  ScrollPosition? _pos;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    final scrollable = Scrollable.maybeOf(context);
    if (MediaQuery.disableAnimationsOf(context) || scrollable == null) {
      _started = true;
      _c.value = 1;
      return;
    }
    final p = scrollable.position;
    if (p != _pos) {
      _pos?.removeListener(_check);
      _pos = p;
      p.addListener(_check);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (_started || !mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    if (top < MediaQuery.sizeOf(context).height * 0.92) {
      _started = true;
      _pos?.removeListener(_check);
      _c.forward();
    }
  }

  @override
  void dispose() {
    _pos?.removeListener(_check);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _c);
}

/// Fades [child] in and slides it from [slide] to its place, during the [from] to [to] part of [t].
Widget _fadeUp(
  Animation<double> t,
  Widget child, {
  double from = 0,
  double to = 1,
  Offset slide = const Offset(0, 22),
}) {
  final curve = Interval(from, to, curve: Curves.easeOutCubic);
  return AnimatedBuilder(
    animation: t,
    child: child,
    builder: (context, ch) {
      final v = curve.transform(t.value);
      return Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(slide.dx * (1 - v), slide.dy * (1 - v)), child: ch),
      );
    },
  );
}

/// Shrinks a little while pressed. A drag (scrolling the row) cancels it.
class _Press extends StatefulWidget {
  const _Press({required this.onTap, required this.label, required this.child});

  final VoidCallback onTap;
  final String label;
  final Widget child;

  @override
  State<_Press> createState() => _PressState();
}

class _PressState extends State<_Press> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

/// A slow breathing pulse (size and brightness) for one small decoration.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});
  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700));
  late final Animation<double> _e = CurvedAnimation(parent: _c, curve: Curves.easeInOut);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
      _c.value = 1;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.9, end: 1.08).animate(_e),
      child: FadeTransition(opacity: Tween<double>(begin: 0.45, end: 1.0).animate(_e), child: widget.child),
    );
  }
}

// ---------------------------------------------------------------- What's on the to-do list?

class TodoBundles extends StatelessWidget {
  const TodoBundles({super.key});

  static const _items = [
    ('Backyard upgrade', 'Lawn, fences, decks', Icons.grass_rounded, [Color(0xFF1F7A4D), Color(0xFF3FB27F)]),
    ('Emergency repairs', 'Plumbing, electrical', Icons.build_rounded, [Color(0xFFB4452C), Color(0xFFE5795B)]),
    ('Home refresh', 'Painting, deep clean', Icons.format_paint_rounded, [Color(0xFF3B4FA8), Color(0xFF6C82E0)]),
    ('Seasonal prep', 'Gutters, heating, snow', Icons.ac_unit_rounded, [Color(0xFF0F6D8C), Color(0xFF3FB4D6)]),
    ('Moving day', 'Moving, junk removal', Icons.local_shipping_rounded, [Color(0xFF6A3FA0), Color(0xFF9B6BD6)]),
  ];

  @override
  Widget build(BuildContext context) {
    return Reveal(
      builder: (context, t) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          _fadeUp(t, const _Title("What's on the to-do list?"), to: 0.5),
          SizedBox(
            height: _scaled(context, 150),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final it = _items[i];
                final start = 0.08 + (i > 3 ? 3 : i) * 0.14;
                return _fadeUp(
                  t,
                  _Press(
                    label: it.$1,
                    onTap: () => context.push('/categories'),
                    child: Container(
                      width: 150,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: it.$4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: Icon(it.$3, size: 20, color: it.$4.first),
                          ),
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
                  from: start,
                  to: start + 0.48,
                  slide: const Offset(28, 0),
                );
              },
            ),
          ),
          const SizedBox(height: 22),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Why Synsyma

class WhySynsyma extends StatelessWidget {
  const WhySynsyma({super.key});

  static const _items = [
    (Icons.verified_user_rounded, 'Verified contractors', 'Every contractor is ID-checked and approved before they work for you.'),
    (Icons.fact_check_rounded, 'Background checked', 'We run a background check before a contractor is approved.'),
    (Icons.lock_rounded, 'Secure payment', 'Pay safely by card. Nothing is charged without your booking.'),
    (Icons.event_repeat_rounded, 'Flexible plans', 'Free cancellation when your job is more than 24 hours away.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18), // room under How it works
        Reveal(
          builder: (context, t) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fadeUp(t, const _Title('Why Synsyma'), to: 0.5),
              SizedBox(
                height: _scaled(context, 148),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final it = _items[i];
                    final start = 0.08 + (i > 3 ? 3 : i) * 0.14;
                    return _fadeUp(
                      t,
                      Container(
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
                      ),
                      from: start,
                      to: start + 0.48,
                      slide: const Offset(28, 0),
                    );
                  },
                ),
              ),
            ],
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
      child: Reveal(
        builder: (context, t) => _fadeUp(
          t,
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.navy, Color(0xFF1B3F8F)]),
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
                      const Text('Pick a service and book the next available contractor.',
                          style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xDDFFFFFF))),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: () => context.push('/categories'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.navy,
                          minimumSize: const Size(0, 44), // the app theme makes buttons full width, this one is a pill
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                        ),
                        child: const Text('Find a service', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const _Pulse(child: Icon(Icons.bolt_rounded, size: 68, color: Color(0x66FFFFFF))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Common questions

class CommonQuestions extends StatelessWidget {
  const CommonQuestions({super.key});

  static const _faq = [
    ('How do you choose a contractor?',
        'Every contractor is verified (ID and background check) before they are approved. We assign the right contractor to your booking and you can see who is coming.'),
    ('Can I cancel or reschedule?',
        'Cancelling is free when no contractor is assigned yet, or when your job is more than 24 hours away. Closer to the time, the cancellation terms apply. Details are in the Terms.'),
    ('How do I pay?',
        'Securely by card when you book. Some jobs need a quote first. Once you accept the quote, you pay by card.'),
    ('What if something goes wrong?',
        'Message support from the Chat tab and we will help. Include your booking so we can find it quickly.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Reveal(
      builder: (context, t) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fadeUp(t, const _Title('Common questions'), to: 0.5),
          _fadeUp(
            t,
            Material(
              // Material (not a coloured Container) so the tiles' ink and background draw correctly
              color: Colors.white,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.fieldBorder),
              ),
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
                        title: Text(_faq[i].$1,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black)),
                        children: [Text(_faq[i].$2, style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF5B6275)))],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            from: 0.1,
          ),
          const SizedBox(height: 22),
        ],
      ),
    );
  }
}