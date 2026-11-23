import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../features/profile/user_profile.dart';
import '../theme/app_theme.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.profile, this.size = 40, this.ring = false});

  final UserProfile profile;
  final double size;
  final bool ring; // white border + shadow, as on the Profile screen

  @override
  Widget build(BuildContext context) {
    final initials = profile.initials;

    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.blueGradient),
      child: initials.isEmpty
          ? Icon(Icons.person_outline, size: size * 0.5, color: Colors.white)
          : Text(
              initials,
              style: TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.w700, color: Colors.white),
            ),
    );

    final photo = profile.photoUrl == null
        ? fallback
        : ClipOval(
            child: CachedNetworkImage(
              imageUrl: profile.photoUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              // decode at the size it is shown (2x for sharp screens) instead of the full photo
              memCacheWidth: (size * 2).round(),
              fadeInDuration: const Duration(milliseconds: 150),
              placeholder: (_, __) => fallback,
              errorWidget: (_, __, ___) => fallback,
            ),
          );

    if (!ring) return SizedBox(width: size, height: size, child: photo);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x1F000000), blurRadius: 14, offset: Offset(0, 4))],
      ),
      child: SizedBox(width: size, height: size, child: photo),
    );
  }
}