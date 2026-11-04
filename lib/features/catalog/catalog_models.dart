class ServiceCategory {
  const ServiceCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.icon,
    this.description,
    this.servicesCount = 0,
  });

  final String id;
  final String name;
  final String slug;
  final String? icon;
  final String? description;
  final int servicesCount;

  factory ServiceCategory.fromJson(Map<String, dynamic> j) => ServiceCategory(
        id: j['id'] as String,
        name: j['name'] as String,
        slug: j['slug'] as String,
        icon: j['icon'] as String?,
        description: j['description'] as String?,
        servicesCount: (j['services_count'] as num?)?.toInt() ?? 0,
      );
}

/// One way to book a service, for example the Premium or the Regular version.
class ServiceOption {
  const ServiceOption({
    required this.id,
    required this.priceLabel,
    this.tier,
    this.tierLabel,
    this.additionalLabel,
    this.partsNote,
    this.teamSize,
    this.description,
  });

  final String id;
  final String? tier; // premium | regular | null
  final String? tierLabel; // "Premium", "Regular" or null
  final String priceLabel; // "$200 (1st 2 hrs)", "$255" or "Get a quote"
  final String? additionalLabel; // "$85 per added hour"
  final String? partsNote;
  final int? teamSize;
  final String? description;

  factory ServiceOption.fromJson(Map<String, dynamic> j) => ServiceOption(
        id: j['id'] as String,
        tier: j['tier'] as String?,
        tierLabel: j['tier_label'] as String?,
        priceLabel: (j['price_label'] as String?) ?? '',
        additionalLabel: j['additional_label'] as String?,
        partsNote: j['parts_note'] as String?,
        teamSize: (j['team_size'] as num?)?.toInt(),
        description: j['description'] as String?,
      );
}

/// A service as the customer sees it: one card, one or more options.
class ServiceCard {
  const ServiceCard({
    required this.id,
    required this.name,
    required this.categoryName,
    required this.categorySlug,
    required this.fromLabel,
    required this.options,
    this.description,
    this.imageUrl,
    this.homeProtection = false,
  });

  final String id;
  final String name;
  final String categoryName;
  final String categorySlug;
  final String fromLabel;
  final String? description;
  final String? imageUrl;
  final bool homeProtection;
  final List<ServiceOption> options;

  factory ServiceCard.fromJson(Map<String, dynamic> j) => ServiceCard(
        id: j['id'] as String,
        name: j['name'] as String,
        categoryName: (j['category_name'] as String?) ?? '',
        categorySlug: (j['category_slug'] as String?) ?? '',
        fromLabel: (j['from_label'] as String?) ?? '',
        description: j['description'] as String?,
        imageUrl: j['image_url'] as String?,
        homeProtection: j['home_protection'] == true,
        options: ((j['options'] as List?) ?? const [])
            .map((e) => ServiceOption.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}
