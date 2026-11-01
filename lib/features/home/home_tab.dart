import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sub_page.dart';
import '../../core/widgets/user_avatar.dart';
import '../profile/profile_controller.dart';
import '../profile/user_profile.dart';
import 'main_tab.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value ?? UserProfile.empty;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          children: [
            Row(
              children: [
                Semantics(
                  button: true,
                  label: 'Open profile',
                  child: GestureDetector(
                    onTap: () => ref.read(mainTabProvider.notifier).select(3),
                    child: UserAvatar(profile: profile, size: 40),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: () => showToast(context, 'No notifications yet.'),
                  icon: const Icon(Icons.notifications_rounded, size: 26, color: Color(0xFF4B5060)),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Text(
              'What Services are you\nlooking for?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.55, color: Colors.black),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Search services',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => showToast(context, 'Search will work once services are added.'),
                      child: Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.authBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.fieldBorder),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.search_rounded, size: 26, color: Color(0xFF6B7280)),
                            SizedBox(width: 12),
                            Text('Search...', style: TextStyle(fontSize: 14, color: Color(0xFF9EA3B0))),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Filter',
                  onPressed: () => showToast(context, 'Filters will work once services are added.'),
                  icon: const Icon(Icons.filter_alt_rounded, size: 28, color: AppColors.navy),
                ),
              ],
            ),
            // Categories, Most Booked and the offer banner come next.
          ],
        ),
      ),
    );
  }
}