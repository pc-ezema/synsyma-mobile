import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand_background.dart';

const onboardingSeenKey = 'onboarding_seen';

class _Slide {
  const _Slide(this.title, this.body, this.image);
  final String title;
  final String body;
  final String image;
}

const _slides = [
  _Slide(
    'Synsyma Is Your No 1 HR Software For Domestic Workers In Nigeria.',
    'Effortlessly connecting employers to home service providers based on availability, proximity and specialization.',
    'assets/images/onboarding_1.png',
  ),
  _Slide(
    'Book A Service',
    'Be rest assured, any new hire sent to your home has successfully passed both safety and security requirements of Synsyma',
    'assets/images/onboarding_2.png',
  ),
  _Slide(
    'Retainership',
    'Synsyma uses AI technology to manage your existing domestic staffs for higher productivity and efficiency.',
    'assets/images/onboarding_3.png',
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  // Each page is 79% of the width, so the neighbouring cards peek in at the edges.
  final _controller = PageController(viewportFraction: 0.79);
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (!_controller.hasClients) return;
      setState(() => _page = _controller.page ?? 0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _go(String route) async {
    await ref.read(storageProvider).write(key: onboardingSeenKey, value: 'true');
    if (mounted) context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_page.round().clamp(0, _slides.length - 1)];
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: BrandBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: LayoutBuilder(
                builder: (context, c) {
                  // Carousel height scales down on short screens.
                  // Space left for the carousel after the buttons (84) and text + indicator (~170).
                  final h = (c.maxHeight - 84 - 170).clamp(240.0, 400.0);
                  final overflow = h * (78 / 397); // how far the head pops above the card

                  return Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                      SizedBox(
                        height: h,
                        child: PageView.builder(
                          controller: _controller,
                          itemCount: _slides.length,
                          itemBuilder: (context, i) => _CardPage(
                            slide: _slides[i],
                            delta: (_page - i).abs().clamp(0.0, 1.0),
                            height: h,
                            overflow: overflow,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 120,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Padding(
                            key: ValueKey(slide.title),
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              children: [
                                Text(
                                  slide.title,
                                  textAlign: TextAlign.center,
                                  style: textTheme.titleSmall?.copyWith(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  slide.body,
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 13,
                                    height: 1.55,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      _PageIndicator(page: _page, count: _slides.length),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _go('/register'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  backgroundColor: AppColors.darkButton,
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: AppColors.blueDark),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                                child: const Text('Sign Up'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _go('/login'),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  backgroundColor: AppColors.blueDark,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                                child: const Text('Login'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One carousel page. The active card is white with the person popping out of
/// the top; neighbouring cards shrink and turn into translucent panels.
class _CardPage extends StatelessWidget {
  const _CardPage({
    required this.slide,
    required this.delta,
    required this.height,
    required this.overflow,
  });

  final _Slide slide;
  final double delta; // 0 = centred, 1 = fully off to the side
  final double height;
  final double overflow;

  @override
  Widget build(BuildContext context) {
    final fullCardH = height - overflow;
    final cardH = fullCardH * (1 - 0.26 * delta);
    final bottomInset = (fullCardH - cardH) / 2; // keep the card centred as it shrinks
    final fill = Color.lerp(Colors.white, Colors.white.withValues(alpha: 0.22), delta)!;

    return Stack(
      children: [
        Positioned(
          left: 11,
          right: 11,
          bottom: bottomInset,
          height: cardH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: -1,
                top: -overflow,
                child: Opacity(
                  opacity: 1 - delta,
                  child: Image.asset(
                    slide.image,
                    fit: BoxFit.cover,
                    alignment: Alignment.bottomCenter,
                    excludeFromSemantics: true,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.person_outline, size: 64, color: AppColors.blueDark),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.page, required this.count});
  final double page;
  final int count;

  static const _track = 100.0;
  static const _thumb = 30.0;

  @override
  Widget build(BuildContext context) {
    final progress = count > 1 ? (page / (count - 1)).clamp(0.0, 1.0) : 0.0;
    return Semantics(
      label: 'Page ${page.round() + 1} of $count',
      child: SizedBox(
        width: _track,
        height: 4,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Positioned(
              left: progress * (_track - _thumb),
              child: Container(
                width: _thumb,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}