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
            child: Image.network(
              profile.photoUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
              loadingBuilder: (_, child, progress) => progress == null ? child : fallback,
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