import 'package:flutter/material.dart';

/// The admin gives each category a short icon key (for example "cleaning").
/// This picks the matching icon. Unknown keys get a neutral one, so a new category never breaks the app.
IconData categoryIcon(String? key, {String? fallbackName}) {
  final k = '${key ?? ''} ${fallbackName ?? ''}'.toLowerCase();

  const map = <String, IconData>{
    'clean': Icons.cleaning_services_rounded,
    'sanitation': Icons.cleaning_services_rounded,
    'repair': Icons.build_rounded,
    'technical': Icons.build_rounded,
    'property': Icons.home_work_rounded,
    'personal': Icons.volunteer_activism_rounded,
    'support': Icons.volunteer_activism_rounded,
    'renovation': Icons.construction_rounded,
    'food': Icons.room_service_rounded,
    'moving': Icons.local_shipping_rounded,
    'relocation': Icons.local_shipping_rounded,
    'lifestyle': Icons.account_tree_rounded,
    'automotive': Icons.car_repair_rounded,
    'car': Icons.car_repair_rounded,
    'eco': Icons.recycling_rounded,
    'technology': Icons.lightbulb_outline_rounded,
    'skilled': Icons.handyman_rounded,
    'outdoor': Icons.park_rounded,
    'lawn': Icons.park_rounded,
    'security': Icons.shield_outlined,
  };

  for (final e in map.entries) {
    if (k.contains(e.key)) return e.value;
  }
  return Icons.grid_view_rounded;
}
