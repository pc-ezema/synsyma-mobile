import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../profile/profile_screen.dart';
import 'home_tab.dart';
import 'main_tab.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(mainTabProvider);

    return PopScope(
      canPop: tab == 0, // back from another tab returns to Home first
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(mainTabProvider.notifier).select(0);
      },
      child: Scaffold(
        backgroundColor: AppColors.authBg,
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: tab,
            children: const [
              HomeTab(),
              _ComingSoon(
                icon: Icons.event_available_outlined,
                title: 'Bookings',
                message: 'Your booked services will show up here.',
              ),
              _ComingSoon(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Chat',
                message: 'Conversations with your service providers will show up here.',
              ),
              ProfileScreen(),
            ],
          ),
        ),
        bottomNavigationBar: AppBottomBar(
          index: tab,
          onSelect: ref.read(mainTabProvider.notifier).select,
        ),
      ),
    );
  }
}

class AppBottomBar extends StatelessWidget {
  const AppBottomBar({super.key, required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  static const _items = [
    (Icons.home_rounded, Icons.home_outlined, 'Home'),
    (Icons.event_available_rounded, Icons.event_available_outlined, 'Booking'),
    (Icons.chat_bubble_rounded, Icons.chat_bubble_outline_rounded, 'Chat'),
    (Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0x14000000))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth / _items.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    left: index * w + (w - 72) / 2,
                    top: 0,
                    width: 72,
                    height: 3,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.blueDark,
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(3)),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < _items.length; i++)
                        Expanded(
                          child: _NavItem(
                            active: i == index,
                            activeIcon: _items[i].$1,
                            icon: _items[i].$2,
                            label: _items[i].$3,
                            onTap: () => onSelect(i),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.active,
    required this.activeIcon,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool active;
  final IconData activeIcon;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              active ? activeIcon : icon,
              size: 26,
              color: active ? AppColors.blueDark : const Color(0xFF8394BC),
            ),
            if (active)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.blueDark),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: Color(0xFFE6F0FE), shape: BoxShape.circle),
              child: Icon(icon, size: 32, color: AppColors.blueDark),
            ),
            const SizedBox(height: 18),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black)),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}