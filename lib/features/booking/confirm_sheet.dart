import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// The same confirm sheet the app uses for Logout: a short question and two buttons.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String yesLabel,
  String noLabel = 'No, keep it',
  bool danger = false,
}) async {
  final yes = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.white,
    constraints: const BoxConstraints(maxWidth: 480),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF4A4E5A))),
          const SizedBox(height: 28),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  foregroundColor: AppColors.blueDark,
                  side: const BorderSide(color: AppColors.blueDark),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                child: Text(noLabel),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: danger ? AppColors.danger : AppColors.blueDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                child: Text(yesLabel),
              ),
            ),
          ]),
        ]),
      ),
    ),
  );
  return yes == true;
}