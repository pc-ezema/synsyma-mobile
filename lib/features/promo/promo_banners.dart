import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sub_page.dart';

class PromoBanner {
  const PromoBanner({required this.id, required this.title, this.subtitle, this.imageUrl, this.linkType = 'none', this.linkValue, this.promoCode});
  final String id;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String linkType; // none | service | category
  final String? linkValue; // service id, or category slug
  final String? promoCode;

  factory PromoBanner.fromJson(Map<String, dynamic> j) => PromoBanner(
        id: j['id'] as String,
        title: j['title'] as String,
        subtitle: j['subtitle'] as String?,
        imageUrl: j['image_url'] as String?,
        linkType: (j['link_type'] as String?) ?? 'none',
        linkValue: j['link_value'] as String?,
        promoCode: j['promo_code'] as String?,
      );
}

/// Home banners. Returns an empty list on any failure so the home screen never shows an error for them.
final bannersProvider = FutureProvider.autoDispose<List<PromoBanner>>((ref) async {
  try {
    final res = await ref.watch(dioProvider).get<dynamic>('/users/banners');
    final data = res.data is Map ? (res.data as Map)['data'] : null;
    return (data is List ? data : const []).map((e) => PromoBanner.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  } on DioException {
    return const <PromoBanner>[];
  }
});

/// Promotions for the Home tab. One banner shows still; two or more slide on their own in a loop and can be swiped.
/// Takes no space when there are none.
class PromoBannerStrip extends ConsumerStatefulWidget {
  const PromoBannerStrip({super.key});

  @override
  ConsumerState<PromoBannerStrip> createState() => _PromoBannerStripState();
}

class _PromoBannerStripState extends ConsumerState<PromoBannerStrip> {
  static const _loopStart = 10000; // lets you swipe either way forever
  final _controller = PageController(initialPage: _loopStart);
  Timer? _timer;
  int _count = 0;
  int _index = 0; // which banner is showing (0 .. count-1)

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    if (_count < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.nextPage(duration: const Duration(milliseconds: 520), curve: Curves.easeInOutCubic);
    });
  }

  void _sync(int count) {
    if (count == _count) return;
    _count = count;
    if (_index >= count) _index = 0;
    _startTimer();
  }

  Future<void> _open(PromoBanner b) async {
    if (b.linkType == 'service' && b.linkValue != null) {
      await context.push('/service/${b.linkValue}');
      return;
    }
    if (b.linkType == 'category' && b.linkValue != null) {
      await context.push('/categories/${b.linkValue}');
      return;
    }
    if (b.promoCode != null) {
      await Clipboard.setData(ClipboardData(text: b.promoCode!));
      if (mounted) showToast(context, 'Code ${b.promoCode} copied. Paste it when you book.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(bannersProvider).value ?? const <PromoBanner>[];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync(list.length);
    });
    if (list.isEmpty) return const SizedBox.shrink();

    final many = list.length > 1;

    return Column(children: [
      SizedBox(
        height: 150,
        // Hold the slideshow while a finger is down, then carry on.
        child: Listener(
          onPointerDown: (_) => _timer?.cancel(),
          onPointerUp: (_) => _startTimer(),
          onPointerCancel: (_) => _startTimer(),
          child: PageView.builder(
            controller: _controller,
            itemCount: many ? null : 1, // null = endless loop
            onPageChanged: (i) => setState(() => _index = i % list.length),
            itemBuilder: (_, i) {
              final b = list[i % list.length];
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  // 0 when this banner is centred, 1 when it is a full page away.
                  var away = 0.0;
                  if (_controller.hasClients && _controller.position.haveDimensions) {
                    away = ((_controller.page ?? _loopStart.toDouble()) - i).abs().clamp(0.0, 1.0);
                  }
                  return Opacity(
                    opacity: 1 - 0.35 * away,
                    child: Transform.scale(scale: 1 - 0.06 * away, child: child),
                  );
                },
                child: _BannerCard(b: b, onTap: () => _open(b)),
              );
            },
          ),
        ),
      ),
      if (many) ...[
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < list.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _index ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(color: i == _index ? AppColors.blueDark : const Color(0xFFC9CEDA), borderRadius: BorderRadius.circular(3)),
            ),
        ]),
      ],
    ]);
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.b, required this.onTap});
  final PromoBanner b;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = b.imageUrl != null;
    return Semantics(
      button: true,
      label: b.title,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: AppColors.blueDark,
          child: InkWell(
            onTap: onTap,
            child: Stack(fit: StackFit.expand, children: [
              if (hasImage)
                Image.network(
                  b.imageUrl!,
                  fit: BoxFit.cover,
                  frameBuilder: (_, child, frame, sync) => sync
                      ? child
                      : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 350), curve: Curves.easeOut, child: child),
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                )
              else
                const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.blueDark, Color(0xFF3D8BFF)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
              // Keeps the white text readable on any photo.
              const DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0x00000000), Color(0xB3000000)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (b.promoCode != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                      child: Text('Use code ${b.promoCode}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.blueDark)),
                    ),
                  Text(b.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2)),
                  if (b.subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(b.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Color(0xE6FFFFFF))),
                  ],
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}