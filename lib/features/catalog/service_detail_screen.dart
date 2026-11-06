import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../home/main_tab.dart';
import 'catalog_models.dart';
import 'catalog_repository.dart';
import 'category_icons.dart';

/// One service with its Premium / Regular options and the Book Now button.
/// Route: /service/:id
class ServiceDetailScreen extends ConsumerStatefulWidget {
  const ServiceDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends ConsumerState<ServiceDetailScreen> {
  String? _selectedId;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(serviceProvider(widget.id));

    return Scaffold(
      backgroundColor: Colors.white,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => SafeArea(
          child: Column(children: [
            Align(alignment: Alignment.centerLeft, child: BackButton(onPressed: () => context.pop())),
            Expanded(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Could not load this service.', style: TextStyle(color: Color(0xFF6B7280))),
                  const SizedBox(height: 10),
                  OutlinedButton(onPressed: () => ref.invalidate(serviceProvider(widget.id)), child: const Text('Try again')),
                ]),
              ),
            ),
          ]),
        ),
        data: _content,
      ),
    );
  }

  Widget _content(ServiceCard s) {
    final selected = s.options.firstWhere(
      (o) => o.id == _selectedId,
      orElse: () => s.options.isNotEmpty ? s.options.first : const ServiceOption(id: '', priceLabel: ''),
    );
    final hasDescription = (s.description ?? '').trim().isNotEmpty;
    final long = (s.description ?? '').length > 140;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _Hero(service: s, onBack: () => context.pop(), onChat: _openChat),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.navy)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(color: const Color(0xFFE3F6EA), borderRadius: BorderRadius.circular(20)),
                      child: Text(s.categoryName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E8E4E))),
                    ),
                    if (hasDescription) ...[
                      const SizedBox(height: 22),
                      const Text('About', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.navy)),
                      const SizedBox(height: 6),
                      Text(
                        s.description!.trim(),
                        maxLines: _expanded || !long ? null : 3,
                        overflow: _expanded || !long ? TextOverflow.visible : TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF6B7280)),
                      ),
                      if (long)
                        GestureDetector(
                          onTap: () => setState(() => _expanded = !_expanded),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(_expanded ? 'see less' : 'see more', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.blueDark)),
                          ),
                        ),
                    ],
                    const SizedBox(height: 22),
                    Text(s.options.length > 1 ? 'Choose a package' : 'Price', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.navy)),
                    const SizedBox(height: 10),
                    for (final o in s.options)
                      _OptionCard(
                        option: o,
                        name: s.name,
                        selectable: s.options.length > 1,
                        selected: o.id == selected.id,
                        onTap: () => setState(() => _selectedId = o.id),
                      ),
                    if (s.homeProtection)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(children: const [
                          Icon(Icons.verified_user_outlined, size: 18, color: Color(0xFF1E8E4E)),
                          SizedBox(width: 6),
                          Expanded(child: Text('Covered by Synsyma Home Protection', style: TextStyle(fontSize: 13, color: Color(0xFF1E8E4E)))),
                        ]),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.blueDark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: selected.id.isEmpty ? null : () => context.push('/book/${selected.id}'),
                child: const Text('Book Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openChat() {
    ref.read(mainTabProvider.notifier).select(2);
    context.go('/home');
  }

}

class _Hero extends StatelessWidget {
  const _Hero({required this.service, required this.onBack, required this.onChat});
  final ServiceCard service;
  final VoidCallback onBack;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 230,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (service.imageUrl != null)
            Image.network(service.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallback())
          else
            _fallback(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _RoundButton(icon: Icons.arrow_back_rounded, label: 'Back', onTap: onBack),
                  _RoundButton(icon: Icons.chat_bubble_outline_rounded, label: 'Chat with us', onTap: onChat),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback() => Container(
        color: const Color(0xFFE6F0FE),
        alignment: Alignment.center,
        child: Icon(categoryIcon(null, fallbackName: service.categorySlug), size: 72, color: AppColors.blueDark),
      );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 1,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 22, color: AppColors.navy)),
          ),
        ),
      );
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.option, required this.name, required this.selectable, required this.selected, required this.onTap});
  final ServiceOption option;
  final String name;
  final bool selectable;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = option.tierLabel == null ? name : '${option.tierLabel} $name';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? const Color(0xFFF1F6FF) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: selectable ? onTap : null,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? AppColors.blueDark : AppColors.fieldBorder, width: selected ? 1.6 : 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selectable)
                  Padding(
                    padding: const EdgeInsets.only(right: 12, top: 1),
                    child: Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, size: 22, color: selected ? AppColors.blueDark : const Color(0xFF9EA3B0)),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.navy)),
                      const SizedBox(height: 4),
                      Text(option.priceLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.blueDark)),
                      if (option.additionalLabel != null) Text(option.additionalLabel!, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                      if (option.teamSize != null && option.teamSize! > 1)
                        Text('Team of ${option.teamSize}', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                      if (option.partsNote != null) Text(option.partsNote!, style: const TextStyle(fontSize: 12, color: Color(0xFF9A6B00))),
                      if ((option.description ?? '').trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(option.description!.trim(), style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF6B7280))),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
