import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sub_page.dart';
import 'catalog_models.dart';
import 'catalog_repository.dart';
import 'category_icons.dart';
import 'category_strip.dart';

/// All categories. Route: /categories
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(categoriesProvider);
    final all = async.value ?? const <ServiceCategory>[];
    final q = _query.trim().toLowerCase();
    final list = q.isEmpty ? all : all.where((c) => c.name.toLowerCase().contains(q)).toList();

    return SubPageScaffold(
      title: 'Category',
      children: [
        _SearchField(hint: 'Search categories...', onChanged: (v) => setState(() => _query = v)),
        const SizedBox(height: 18),
        if (async.isLoading && all.isEmpty)
          const Padding(padding: EdgeInsets.only(top: 48), child: Center(child: CircularProgressIndicator()))
        else if (async.hasError && all.isEmpty)
          _Message(text: 'Could not load categories.', action: 'Try again', onAction: () => ref.invalidate(categoriesProvider))
        else if (list.isEmpty)
          _Message(text: all.isEmpty ? 'No services are available yet.' : 'No categories found.')
        else
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 0.86,
            children: [
              for (final c in list)
                CategoryTile(
                  label: c.name,
                  icon: categoryIcon(c.icon, fallbackName: c.name),
                  onTap: () => context.push('/categories/${c.slug}'),
                ),
            ],
          ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.hint, required this.onChanged});
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 14, color: AppColors.navy),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9EA3B0)),
        prefixIcon: const Icon(Icons.search_rounded, size: 26, color: Color(0xFF6B7280)),
        filled: true,
        fillColor: AppColors.authBg,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.fieldBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.fieldBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.blueDark, width: 1.6)),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Center(
          child: Column(children: [
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280))),
            if (action != null) ...[
              const SizedBox(height: 10),
              OutlinedButton(onPressed: onAction, child: Text(action!)),
            ],
          ]),
        ),
      );
}
