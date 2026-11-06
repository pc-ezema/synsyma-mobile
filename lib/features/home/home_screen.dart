import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../chat/chat_unread.dart';
import '../profile/profile_screen.dart';
import '../chat/chat_tab.dart';
import 'home_tab.dart';
import 'main_tab.dart';
import '../booking/bookings_tab.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(mainTabProvider);
    final chatUnread = ref.watch(chatUnreadProvider);

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
              BookingsTab(),
              ChatTab(),
              ProfileScreen(),
            ],
          ),
        ),
        bottomNavigationBar: AppBottomBar(
          index: tab,
          onSelect: ref.read(mainTabProvider.notifier).select,
          chatUnread: chatUnread,
        ),
      ),
    );
  }
}

class AppBottomBar extends StatelessWidget {
  const AppBottomBar({super.key, required this.index, required this.onSelect, this.chatUnread = 0});

  final int index;
  final ValueChanged<int> onSelect;
  final int chatUnread; // unread messages from support, shown on the Chat tab

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
                            badge: i == 2 ? chatUnread : 0,
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
    this.badge = 0,
  });

  final bool active;
  final IconData activeIcon;
  final IconData icon;
  final String label;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: badge > 0 ? '$label, $badge unread' : label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  active ? activeIcon : icon,
                  size: 26,
                  color: active ? AppColors.blueDark : const Color(0xFF8394BC),
                ),
                if (badge > 0)
                  Positioned(
                    right: -9,
                    top: -5,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        badge > 9 ? '9+' : '$badge',
                        textScaler: TextScaler.noScaling, // stays small even with the text boost
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white, height: 1),
                      ),
                    ),
                  ),
              ],
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