# Catalog: Flutter wiring

Files go in lib/features/catalog/. Add `import '../../features/catalog/...'` lines in app_router.dart.

## 1. Routes (app_router.dart, next to /help and /profile/delete)

    GoRoute(path: '/categories', builder: (_, __) => const CategoriesScreen()),
    GoRoute(path: '/categories/:slug', builder: (_, s) => CategoryServicesScreen(slug: s.pathParameters['slug']!)),
    GoRoute(path: '/service/:id', builder: (_, s) => ServiceDetailScreen(id: s.pathParameters['id']!)),

If your router has a signed-in redirect list, make sure these three paths are allowed after login.

## 2. Home tab (home_tab.dart)

Import `../catalog/category_strip.dart`, then under the search field:

    const SizedBox(height: 16),
    const CategoryStrip(),

## 3. Backend
See the Laravel notes: copy CatalogController into Modules/Service, add the three routes in the auth:sanctum v1 group.
