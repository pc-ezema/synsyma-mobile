import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sub_page.dart';
import 'booking_models.dart';
import 'booking_repository.dart';
import 'booking_widgets.dart';

/// Saved addresses. Route: /addresses   (or /addresses?select=1 to pick one for a booking)
class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key, this.selectMode = false});
  final bool selectMode;

  Future<void> _openForm(BuildContext context, WidgetRef ref, {SavedAddress? existing}) async {
    final saved = await context.push<SavedAddress>('/addresses/form', extra: existing);
    if (saved == null) return;
    ref.invalidate(addressesProvider);
    if (selectMode && context.mounted) context.pop(saved.id); // go straight back with the new one
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, SavedAddress a) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Delete this address?'),
        content: Text('${a.title}\n${a.oneLine}\n\nYour past bookings keep their own copy of the address.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await ref.read(bookingRepositoryProvider).deleteAddress(a.id);
      ref.invalidate(addressesProvider);
    } on ApiError catch (e) {
      if (context.mounted) showToast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(addressesProvider);
    final list = async.value ?? const <SavedAddress>[];

    return SubPageScaffold(
      title: selectMode ? 'Choose address' : 'My addresses',
      children: [
        if (async.isLoading && list.isEmpty)
          const Padding(padding: EdgeInsets.only(top: 48), child: Center(child: CircularProgressIndicator()))
        else if (async.hasError && list.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Column(children: [
              const Text('Could not load your addresses.', style: TextStyle(color: Color(0xFF6B7280))),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: () => ref.invalidate(addressesProvider), child: const Text('Try again')),
            ]),
          )
        else if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Column(children: [
              Icon(Icons.location_on_outlined, size: 44, color: Color(0xFF9CA3AF)),
              SizedBox(height: 10),
              Text('No saved addresses yet.', style: TextStyle(color: Color(0xFF6B7280))),
            ]),
          )
        else
          for (final a in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: selectMode ? () => context.pop(a.id) : () => _openForm(context, ref, existing: a),
                child: GlassCard(
                  padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                  child: Row(children: [
                    const IconTile(Icons.location_on_outlined),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Flexible(child: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black))),
                          if (a.isDefault) ...[
                            const SizedBox(width: 8),
                            const CategoryPill('Default'),
                          ],
                        ]),
                        const SizedBox(height: 3),
                        Text(a.oneLine, style: const TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF6B7280))),
                      ]),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF6B7280)),
                      onSelected: (v) => v == 'edit' ? _openForm(context, ref, existing: a) : _delete(context, ref, a),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ]),
                ),
              ),
            ),
        const SizedBox(height: 8),
        PrimaryButton(label: 'Add a new address', onPressed: () => _openForm(context, ref)),
      ],
    );
  }
}
