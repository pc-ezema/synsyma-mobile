import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class SubPageScaffold extends StatelessWidget {
  const SubPageScaffold({
    super.key,
    required this.title,
    required this.children,
    this.fadeBottom = false,
  });

  final String title;
  final List<Widget> children;
  final bool fadeBottom; // soft fade at the bottom edge (Terms screen)

  @override
  Widget build(BuildContext context) {
    // Browsers have no status bar, so top up to the design's 44px.
    final inset = MediaQuery.paddingOf(context).top;
    final extraTop = inset < 44 ? 44 - inset : 0.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.authBg,
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  SizedBox(height: extraTop),
                  SizedBox(
                    height: 56,
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Back',
                          icon: const Icon(Icons.chevron_left_rounded, size: 30, color: AppColors.navy),
                          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        SingleChildScrollView(
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
                        ),
                        if (fadeBottom)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 90,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [AppColors.authBg.withValues(alpha: 0), AppColors.authBg],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}