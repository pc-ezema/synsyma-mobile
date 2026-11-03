import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/sub_page.dart';
import '../home/main_tab.dart';
import '../profile/profile_controller.dart';
import 'support_contact.dart';

/// Help & Feedback. Route: /help
/// Phone numbers and emails come from the admin dashboard. WhatsApp is the floating button.
class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  static const _whatsappGreen = Color(0xFF25D366);

  Future<void> _open(BuildContext context, Uri uri, String failMessage) async {
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && context.mounted) showToast(context, failMessage);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(supportContactsProvider);
    final firstName = (ref.watch(profileProvider).value?.fullName ?? '').trim().split(' ').first;

    final all = contacts.value ?? const <SupportContact>[];
    final phones = all.where((c) => c.type == ContactType.phone).toList();
    final emails = all.where((c) => c.type == ContactType.email).toList();
    final whatsapp = all.where((c) => c.type == ContactType.whatsapp).firstOrNull;

    final whatsappButton = whatsapp == null
        ? null
        : FloatingActionButton.extended(
            heroTag: 'help-whatsapp',
            onPressed: () {
              final digits = whatsapp.value.replaceAll(RegExp(r'[^0-9]'), '');
              _open(context, Uri.parse('https://wa.me/$digits'), 'Could not open WhatsApp.');
            },
            backgroundColor: _whatsappGreen,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.chat_rounded),
            label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.w700)),
          );

    // Material so the floating button works outside a Scaffold; the button floats above the page.
    return Material(
      type: MaterialType.transparency,
      child: Stack(children: [
        SubPageScaffold(
          title: 'Help & Support',
          children: [
            Text(firstName.isEmpty ? 'Hi there' : 'Hi $firstName',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black, height: 1.35)),
            const Text('How can we help?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black, height: 1.35)),
            const SizedBox(height: 22),
            _Card(children: [
              _Row(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Send us a message',
                onTap: () {
                  context.pop(); // close Help, then show the Chat tab
                  ref.read(mainTabProvider.notifier).state = 2; // TODO(3 of 3): your Chat tab index / setter
                },
              ),
            ]),
            if (contacts.isLoading)
              const Padding(padding: EdgeInsets.only(top: 36), child: Center(child: CircularProgressIndicator()))
            else if (contacts.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 28),
                child: Center(
                  child: Column(children: [
                    const Text('Could not load our contact details.', style: TextStyle(color: Color(0xFF6B7280))),
                    const SizedBox(height: 8),
                    OutlinedButton(onPressed: () => ref.invalidate(supportContactsProvider), child: const Text('Try again')),
                  ]),
                ),
              )
            else ...[
              if (phones.isNotEmpty) ...[
                const _Heading('Call us'),
                _Card(children: [
                  for (final c in phones)
                    _Row(
                      icon: Icons.phone_outlined,
                      title: c.value,
                      subtitle: c.label,
                      onTap: () => _open(context, Uri(scheme: 'tel', path: c.value), 'Could not open the phone app.'),
                    ),
                ]),
              ],
              if (emails.isNotEmpty) ...[
                const _Heading('Email us'),
                _Card(children: [
                  for (final c in emails)
                    _Row(
                      icon: Icons.mail_outline_rounded,
                      title: c.value,
                      subtitle: c.label,
                      onTap: () => _open(context, Uri(scheme: 'mailto', path: c.value), 'Could not open the mail app.'),
                    ),
                ]),
              ],
            ],
            if (whatsappButton != null) const SizedBox(height: 70), // room so the button never covers the last row
          ],
        ),
        if (whatsappButton != null)
          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.paddingOf(context).bottom + 20),
                  child: Align(alignment: Alignment.bottomRight, child: whatsappButton),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 0, 8),
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
      );
}

// Same look as the cards and rows on the Profile screen.
class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white),
        ),
        child: Column(children: children),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.onTap, this.subtitle});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: const Color(0xFFE7E9EF), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 20, color: AppColors.navy),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: subtitle == null || subtitle!.isEmpty
                  ? Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF4A4E5A)))
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(subtitle!, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                      const SizedBox(height: 2),
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black)),
                    ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF6B7280)),
          ]),
        ),
      );
}