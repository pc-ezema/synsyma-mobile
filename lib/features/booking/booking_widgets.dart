import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'booking_models.dart';

/// Same look as the cards on the Profile and Help screens.
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 6), this.radius = 20});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white),
        ),
        child: child,
      );
}

/// Small grey heading above a card, like "Email us" on the Help screen.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 0, 8),
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
      );
}

class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key});
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: const Color(0xFFE7E9EF), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 20, color: AppColors.navy),
      );
}

/// A label on the left and its value on the right.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.bold = false});
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: bold ? Colors.black : const Color(0xFF4A4E5A))),
          const SizedBox(width: 16),
          Expanded(
            child: Text(value, textAlign: TextAlign.right, style: TextStyle(fontSize: bold ? 15 : 14, height: 1.4, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: Colors.black)),
          ),
        ]),
      );
}

/// Rows with a hairline between them.
class InfoList extends StatelessWidget {
  const InfoList({super.key, required this.rows});
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < rows.length; i++) ...[
          rows[i],
          if (i < rows.length - 1) const Divider(height: 1, color: Color(0xFFE3E6EE)),
        ],
      ]);
}

/// The service photo, with a soft icon tile when there is no photo.
class BookingThumb extends StatelessWidget {
  const BookingThumb({super.key, this.url, required this.width});
  final String? url;
  final double width;

  Widget _fallback() => Container(
        width: width,
        color: const Color(0xFFE6F0FE),
        child: const Center(child: Icon(Icons.home_repair_service_outlined, size: 32, color: AppColors.blueDark)),
      );

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: url == null
            ? _fallback()
            : Image.network(
                url!,
                width: width,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, p) => p == null ? child : _fallback(),
                errorBuilder: (_, __, ___) => _fallback(),
              ),
      );
}

class CategoryPill extends StatelessWidget {
  const CategoryPill(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xFFE6F0FE), borderRadius: BorderRadius.circular(8)),
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0057D9))),
      );
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = statusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(statusText(status), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

/// The blue primary button used across the app.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.busy = false});
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.blueDark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: busy ? null : onPressed,
          child: busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
              : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      );
}
