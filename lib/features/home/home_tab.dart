import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/user_avatar.dart';
import '../catalog/category_strip.dart';
import '../profile/profile_controller.dart';
import '../profile/user_profile.dart';
import '../promo/promo_banners.dart';
import 'main_tab.dart';
import '../notifications/notification_bell.dart';
import 'home_repository.dart';
import 'home_sections.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value ?? UserProfile.empty;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(popularServicesProvider);
            ref.invalidate(homeSummaryProvider);
            try {
              await ref.read(homeSummaryProvider.future);
            } catch (_) {
              // the blocks just stay hidden if it fails
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                  const NotificationBell(),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                'What Services are you\nlooking for?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.55, color: Colors.black),
              ),
              const SizedBox(height: 18),
              const ActionStrip(), // only when something is waiting on them
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: 'Search services',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => context.push('/categories'),
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
                    onPressed: () => context.push('/categories'),
                    icon: const Icon(Icons.filter_alt_rounded, size: 28, color: AppColors.navy),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const PromoBannerStrip(),
              const SizedBox(height: 22),
              const NextJobCard(), // only when they have an upcoming job
              const Text(
                'Category',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black),
              ),
              const SizedBox(height: 10),
              const CategoryStrip(),
              const SizedBox(height: 22),
              const MostBookedRow(),
              const BookAgainRow(), // only once they have had a job done
              const HowItWorks(), // only for new customers
            ],
          ),
        ),
      ),
    );
  }
}