import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import 'push_service.dart';

/// Opens the Push debug sheet. Show its entry only when Env.name != 'prod'.
Future<void> showPushDebug(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    constraints: const BoxConstraints(maxWidth: 480),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => const _PushDebugSheet(),
  );
}

class _PushDebugSheet extends ConsumerWidget {
  const _PushDebugSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Push debug', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black)),
            const SizedBox(height: 4),
            const Text('What happened when this phone tried to register for notifications.', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.45),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.authBg, borderRadius: BorderRadius.circular(12)),
                child: ValueListenableBuilder<List<String>>(
                  valueListenable: pushDebugLog,
                  builder: (_, lines, __) => SingleChildScrollView(
                    child: SelectableText(lines.join('\n\n'), style: const TextStyle(fontSize: 12.5, height: 1.35, color: Colors.black)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: pushDebugLog.value.join('\n')));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
                  },
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: AppColors.blueDark, side: const BorderSide(color: AppColors.blueDark), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text('Copy'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => ref.read(pushServiceProvider).registerDevice(),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: AppColors.blueDark, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text('Register now'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}