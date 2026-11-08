import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sub_page.dart';
import '../booking/booking_widgets.dart';
import '../booking/confirm_sheet.dart';
import 'saved_cards.dart';

/// Profile > Saved cards. Route: /cards
class SavedCardsScreen extends ConsumerStatefulWidget {
  const SavedCardsScreen({super.key});

  @override
  ConsumerState<SavedCardsScreen> createState() => _SavedCardsScreenState();
}

class _SavedCardsScreenState extends ConsumerState<SavedCardsScreen> {
  String? _removing;

  Future<void> _remove(SavedCard c) async {
    final yes = await showConfirmSheet(
      context,
      title: 'Remove this card?',
      message: '${c.brandLabel} ending ${c.last4} will be removed. You can add it again the next time you pay.',
      yesLabel: 'Yes, remove it',
      noLabel: 'No, keep it',
      danger: true,
    );
    if (!yes || !mounted) return;

    setState(() => _removing = c.id);
    try {
      await ref.read(cardsRepositoryProvider).remove(c.id);
      ref.invalidate(savedCardsProvider);
      if (mounted) showToast(context, 'Card removed.');
    } on ApiError catch (e) {
      if (mounted) showToast(context, e.message);
    } finally {
      if (mounted) setState(() => _removing = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(savedCardsProvider);

    return SubPageScaffold(
      title: 'Saved cards',
      children: [
        cards.when(
          loading: () => const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Column(children: [
              Text(e is ApiError ? e.message : 'Could not load your cards.', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280))),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: () => ref.invalidate(savedCardsProvider), child: const Text('Try again')),
            ]),
          ),
          data: (list) => list.isEmpty
              ? const Padding(
                  padding: EdgeInsets.only(top: 50),
                  child: Column(children: [
                    Icon(Icons.credit_card_off_outlined, size: 52, color: Color(0xFF9CA3AF)),
                    SizedBox(height: 12),
                    Text('No saved cards', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black)),
                    SizedBox(height: 6),
                    Text('When you pay by card, you can choose to save it for next time.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, height: 1.45, color: Color(0xFF6B7280))),
                  ]),
                )
              : Column(children: [
                  for (final c in list) ...[
                    GlassCard(
                      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                      child: Row(children: [
                        const IconTile(Icons.credit_card_rounded),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${c.brandLabel} •••• ${c.last4}', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Colors.black)),
                            const SizedBox(height: 2),
                            Text(
                              c.expired ? 'Expired ${c.expiry}' : 'Expires ${c.expiry}',
                              style: TextStyle(fontSize: 12.5, color: c.expired ? AppColors.danger : const Color(0xFF6B7280)),
                            ),
                          ]),
                        ),
                        _removing == c.id
                            ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2)))
                            : IconButton(
                                tooltip: 'Remove card',
                                onPressed: () => _remove(c),
                                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                              ),
                      ]),
                    ),
                    const SizedBox(height: 12),
                  ],
                ]),
        ),
        const SizedBox(height: 14),
        const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF6B7280)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Your card details are stored securely by Stripe. Synsyma never sees or keeps your full card number.',
              style: TextStyle(fontSize: 12.5, height: 1.45, color: Color(0xFF6B7280)),
            ),
          ),
        ]),
      ],
    );
  }
}