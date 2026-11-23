import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sub_page.dart';
import 'catalog_models.dart';
import 'catalog_repository.dart';
import 'category_icons.dart';

/// The services in one category. Route: /categories/:slug
class CategoryServicesScreen extends ConsumerStatefulWidget {
  const CategoryServicesScreen({super.key, required this.slug});
  final String slug;

  @override
  ConsumerState<CategoryServicesScreen> createState() => _CategoryServicesScreenState();
}

class _CategoryServicesScreenState extends ConsumerState<CategoryServicesScreen> {
  String _query = '';
  final _warmed = <String>{}; // image URLs already requested in the background

  /// Start downloading every photo at once, so tiles don't wait for each other.
  void _warm(List<ServiceCard> services) {
    for (final s in services) {
      final url = s.imageUrl;
      if (url == null || !_warmed.add(url)) continue;
      precacheImage(CachedNetworkImageProvider(url), context).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(categoryServicesProvider(widget.slug));
    final all = async.value ?? const <ServiceCard>[];
    if (all.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _warm(all);
      });
    }

    // The title comes from the loaded services, or from the category list if it is already cached.
    final fromCategories = ref.watch(categoriesProvider).value?.where((c) => c.slug == widget.slug).firstOrNull;
    final title = fromCategories?.name ?? (all.isNotEmpty ? all.first.categoryName : 'Services');

    final q = _query.trim().toLowerCase();
    final list = q.isEmpty ? all : all.where((s) => s.name.toLowerCase().contains(q)).toList();

    return SubPageScaffold(
      title: title,
      children: [
        TextField(
          onChanged: (v) => setState(() => _query = v),
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 14, color: AppColors.navy),
          decoration: InputDecoration(
            hintText: 'Search...',
            hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9EA3B0)),
            prefixIcon: const Icon(Icons.search_rounded, size: 26, color: Color(0xFF6B7280)),
            filled: true,
            fillColor: AppColors.authBg,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.fieldBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.fieldBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.blueDark, width: 1.6)),
          ),
        ),
        const SizedBox(height: 18),
        if (async.isLoading && all.isEmpty)
          const Padding(padding: EdgeInsets.only(top: 48), child: Center(child: CircularProgressIndicator()))
        else if (async.hasError && all.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Center(
              child: Column(children: [
                const Text('Could not load services.', style: TextStyle(color: Color(0xFF6B7280))),
                const SizedBox(height: 10),
                OutlinedButton(onPressed: () => ref.invalidate(categoryServicesProvider(widget.slug)), child: const Text('Try again')),
              ]),
            ),
          )
        else if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Center(child: Text(all.isEmpty ? 'No services here yet.' : 'No services found.', style: const TextStyle(color: Color(0xFF6B7280)))),
          )
        else
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.78,
            children: [for (final s in list) _ServiceTile(service: s, onTap: () => context.push('/service/${s.id}'))],
          ),
      ],
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service, required this.onTap});
  final ServiceCard service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${service.name}, ${service.fromLabel}',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: service.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: service.imageUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        memCacheWidth: 360, // the tile is about 120 px wide, so decode small
                        fadeInDuration: const Duration(milliseconds: 150),
                        placeholder: (_, __) => _Placeholder(service: service),
                        errorWidget: (_, __, ___) => _Placeholder(service: service),
                      )
                    : _Placeholder(service: service),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                child: Text(
                  service.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.25, color: AppColors.navy),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown while a photo loads, and for services that have no photo.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.service});
  final ServiceCard service;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: const Color(0xFFE6F0FE),
        alignment: Alignment.center,
        child: Icon(categoryIcon(null, fallbackName: service.categorySlug), size: 34, color: AppColors.blueDark),
      );
}