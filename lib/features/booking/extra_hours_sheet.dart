import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'booking_models.dart';

/// Choose how many extra hours to add. Returns the number, or null if the customer closes the sheet.
Future<int?> pickExtraHours(BuildContext context, BookingOptions o) {
  var hours = 1;
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.white,
    constraints: const BoxConstraints(maxWidth: 480),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        Widget step(IconData icon, bool enabled, VoidCallback onTap) => Material(
              color: enabled ? const Color(0xFFE7E9EF) : const Color(0xFFF1F2F6),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: enabled ? onTap : null,
                child: SizedBox(width: 44, height: 44, child: Icon(icon, color: enabled ? AppColors.navy : const Color(0xFFB5BAC6))),
              ),
            );

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Add extra hours', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)),
              const SizedBox(height: 10),
              Text(
                '${money(o.pricePerHour, o.currency)} per extra hour. You can add up to ${o.maxMoreHours} more.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, height: 1.45, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 22),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                step(Icons.remove_rounded, hours > 1, () => setSheet(() => hours--)),
                SizedBox(
                  width: 120,
                  child: Column(children: [
                    Text('$hours', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: Colors.black)),
                    Text(hours == 1 ? 'hour' : 'hours', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                  ]),
                ),
                step(Icons.add_rounded, hours < o.maxMoreHours, () => setSheet(() => hours++)),
              ]),
              const SizedBox(height: 18),
              Text('Total  ${money(o.pricePerHour * hours, o.currency)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black)),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      foregroundColor: AppColors.blueDark,
                      side: const BorderSide(color: AppColors.blueDark),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    child: const Text('Not now'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, hours),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: AppColors.blueDark,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    child: const Text('Continue'),
                  ),
                ),
              ]),
            ]),
          ),
        );
      },
    ),
  );
}