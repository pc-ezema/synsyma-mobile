import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sub_page.dart';
import '../../core/widgets/user_avatar.dart';
import '../auth/auth_controller.dart';
import '../home/main_tab.dart';
import 'profile_controller.dart';
import 'user_profile.dart';
import '../../core/config/env.dart';
import '../push/push_debug.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(profileProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Couldn’t load your profile.'),
                  if (Env.name != 'prod') ...[
                    const SizedBox(height: 8),
                    Text(
                      e is ApiError ? e.message : '$e',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(profileProvider),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
          data: (p) => _ProfileBody(profile: p),
        );
  }
}

class _ProfileBody extends ConsumerStatefulWidget {
  const _ProfileBody({required this.profile});
  final UserProfile profile;

  @override
  ConsumerState<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends ConsumerState<_ProfileBody> {
  bool _uploading = false;

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
      if (file == null) return;
      setState(() => _uploading = true);
      final bytes = await file.readAsBytes();
      final name = file.name.contains('.') ? file.name : '${file.name}.jpg';
      await ref.read(profileProvider.notifier).uploadPhoto(bytes, name);
      if (mounted) showToast(context, 'Profile photo updated.');
    } on ApiError catch (e) {
      if (mounted) showToast(context, e.message);
    } on PlatformException {
      if (mounted) showToast(context, 'Could not open the photo picker.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _remove() async {
    setState(() => _uploading = true);
    try {
      await ref.read(profileProvider.notifier).removePhoto();
      if (mounted) showToast(context, 'Profile photo removed.');
    } on ApiError catch (e) {
      if (mounted) showToast(context, e.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _photoSheet(UserProfile p) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 480),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.gallery);
              },
            ),
            if (p.photoUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                title: const Text('Remove photo', style: TextStyle(color: AppColors.danger)),
                onTap: () {
                  Navigator.pop(ctx);
                  _remove();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          children: [
            Row(
              children: [
                const Text(
                  'Profile',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: () => showToast(context, 'No notifications yet.'),
                  icon: const Icon(Icons.notifications_rounded, size: 26, color: Color(0xFF4B5060)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Stack(
                children: [
                  UserAvatar(profile: p, size: 100, ring: true),
                  if (_uploading)
                    Positioned.fill(
                      child: Container(
                        margin: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Color(0x66000000), shape: BoxShape.circle),
                        child: const Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Semantics(
                      button: true,
                      label: 'Change photo',
                      child: Material(
                        color: const Color(0xFFE3E7EF),
                        shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 2)),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _uploading ? null : () => _photoSheet(p),
                          child: const SizedBox(
                            width: 32,
                            height: 32,
                            child: Icon(Icons.edit_outlined, size: 16, color: AppColors.blueDark),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                p.fullName,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black),
              ),
            ),
            const SizedBox(height: 22),
            _Card(children: [
              _Row(
                icon: Icons.person_outline_rounded,
                title: 'Name',
                value: p.fullName,
                onTap: () => context.push('/profile/edit/name'),
              ),
              _Row(
                icon: Icons.phone_outlined,
                title: 'Phone Number',
                value: p.phone ?? 'Add phone number',
                placeholder: p.phone == null,
                onTap: () => context.push('/profile/edit/phone'),
              ),
              _Row(
                icon: Icons.mail_outline_rounded,
                title: 'Email',
                value: p.email,
                onTap: () => context.push('/profile/edit/email'),
              ),
              _Row(
                icon: Icons.location_on_outlined,
                title: 'Address',
                value: p.address ?? 'Add address',
                placeholder: p.address == null,
                onTap: () => context.push('/profile/edit/address'),
              ),
            ]),
            const SizedBox(height: 18),
            _Card(children: [
              _Row(
                icon: Icons.lock_outline_rounded,
                title: 'Update Password',
                onTap: () => context.push('/profile/password'),
              ),
              _Row(
                icon: Icons.location_on_outlined,
                title: 'My addresses',
                onTap: () => context.push('/addresses'),
              ),
              _Row(
                icon: Icons.credit_card_rounded,
                title: 'Saved cards',
                onTap: () => context.push('/cards'),
              ),
              _Row(
                icon: Icons.help_outline_rounded,
                title: 'Help & Support',
                onTap: () => context.push('/help'),
              ),
              _Row(
                icon: Icons.description_outlined,
                title: 'Terms & Condition',
                onTap: () => context.push('/terms'),
              ),
              if (Env.name == 'local')
              _Row(
                icon: Icons.bug_report_outlined,
                title: 'Push debug',
                onTap: () => showPushDebug(context),
              ),
            ]),
            const SizedBox(height: 18),
            _Card(children: [
              _Row(
                icon: Icons.delete_outline_rounded,
                title: 'Delete account',
                danger: true,
                chevron: false,
                onTap: () => context.push('/profile/delete'),
              ),
              _Row(
                icon: Icons.logout_rounded,
                title: 'Logout',
                danger: true,
                chevron: false,
                onTap: () => confirmLogout(context, ref),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

Future<void> confirmLogout(BuildContext context, WidgetRef ref) async {
  final yes = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.white,
    constraints: const BoxConstraints(maxWidth: 480),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280)),
                onPressed: () => Navigator.pop(ctx, false),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Are you sure you want to logout?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      foregroundColor: AppColors.blueDark,
                      side: const BorderSide(color: AppColors.blueDark),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    child: const Text('No, Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: AppColors.blueDark,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    child: const Text('Yes, Logout'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  if (yes == true) {
    ref.invalidate(mainTabProvider); // next login starts on Home
    await ref.read(authProvider.notifier).logout(); // the router sends them to /login
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white),
      ),
      child: Column(children: children),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.onTap,
    this.value,
    this.placeholder = false,
    this.danger = false,
    this.chevron = true,
  });

  final IconData icon;
  final String title;
  final String? value;
  final bool placeholder;
  final bool danger;
  final bool chevron;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE7E9EF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: danger ? AppColors.danger : AppColors.navy),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: value == null
                  ? Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: danger ? AppColors.danger : const Color(0xFF4A4E5A),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                        const SizedBox(height: 2),
                        Text(
                          value!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: placeholder ? FontWeight.w500 : FontWeight.w600,
                            color: placeholder ? AppColors.blueDark : Colors.black,
                          ),
                        ),
                      ],
                    ),
            ),
            if (chevron) const Icon(Icons.chevron_right_rounded, color: Color(0xFF6B7280)),
          ],
        ),
      ),
    );
  }
}