import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import 'catalog_models.dart';
import 'catalog_repository.dart';
import 'category_icons.dart';

/// "Category" row for the Home tab: the first three categories and a "More" tile.
/// Drop `const CategoryStrip()` into HomeTab under the search field.
class CategoryStrip extends ConsumerWidget {
  const CategoryStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final list = categories.value ?? const <ServiceCategory>[];

    if (categories.isLoading && list.isEmpty) {
      return Row(children: [for (var i = 0; i < 4; i++) const Expanded(child: _Skeleton())]);
    }
    if (list.isEmpty) return const SizedBox.shrink(); // nothing to show yet, or offline

    final shown = list.take(3).toList();

    return Row(
      children: [
        for (final c in shown)
          Expanded(child: CategoryTile(label: c.name, icon: categoryIcon(c.icon, fallbackName: c.name), onTap: () => context.push('/categories/${c.slug}'))),
        for (var i = shown.length; i < 3; i++) const Expanded(child: SizedBox()),
        Expanded(child: CategoryTile(label: 'More', icon: Icons.more_horiz_rounded, onTap: () => context.push('/categories'))),
      ],
    );
  }
}

class CategoryTile extends StatelessWidget {
  const CategoryTile({super.key, required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(color: Color(0xFFE6F0FE), shape: BoxShape.circle),
                    child: Icon(icon, size: 26, color: AppColors.blueDark),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 34,
                    child: Center(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, height: 1.25, color: AppColors.navy),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(4),
        child: Container(height: 100, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12))),
      );
}
