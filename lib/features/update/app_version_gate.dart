import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';

/// The installed version (e.g. "1.0.3"), set once in main() from package_info_plus.
String kAppVersion = '0.0.0';
String get kAppPlatform => Platform.isIOS ? 'ios' : 'android';

class VersionStatus {
  const VersionStatus({this.force = false, this.soft = false, this.storeUrl, this.message, this.latest});
  final bool force;
  final bool soft;
  final String? storeUrl;
  final String? message;
  final String? latest;
}

/// -1, 0, 1. Compares numbers, so 1.2.10 is newer than 1.2.9. Ignores any +build or -suffix.
int compareVersions(String a, String b) {
  List<int> parse(String v) {
    final core = v.split(RegExp(r'[+-]')).first.trim();
    final p = core.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    while (p.length < 3) {
      p.add(0);
    }
    return p;
  }

  final x = parse(a), y = parse(b);
  for (var i = 0; i < 3; i++) {
    if (x[i] != y[i]) return x[i] < y[i] ? -1 : 1;
  }
  return 0;
}

/// Set to true by the Dio interceptor when the server answers 426 Upgrade Required.
class ForceUpdateFlag extends Notifier<bool> {
  @override
  bool build() => false;
  void raise() => state = true;
}

final forceUpdateFlagProvider = NotifierProvider<ForceUpdateFlag, bool>(ForceUpdateFlag.new);

/// If the check fails (offline, server down) nobody is locked out.
final versionStatusProvider = FutureProvider<VersionStatus>((ref) async {
  try {
    final res = await ref.watch(dioProvider).get<dynamic>(
      '/app/version',
      queryParameters: {'platform': kAppPlatform},
      options: Options(method: 'GET'),
    );
    final json = res.data;
    final d = json is Map ? json['data'] : null;
    if (d is! Map) return const VersionStatus();
    final min = d['min_version']?.toString() ?? '0.0.0';
    final latest = d['latest_version']?.toString() ?? '0.0.0';
    return VersionStatus(
      force: compareVersions(kAppVersion, min) < 0,
      soft: compareVersions(kAppVersion, latest) < 0,
      storeUrl: d['store_url']?.toString(),
      message: d['message']?.toString(),
      latest: latest,
    );
  } catch (_) {
    return const VersionStatus();
  }
});

const _store = FlutterSecureStorage();
const _softKey = 'update_nudge_day';

/// Wrap the whole app (MaterialApp.builder). Blocks the app when too old, nudges when a newer version exists.
class AppVersionGate extends ConsumerStatefulWidget {
  const AppVersionGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppVersionGate> createState() => _AppVersionGateState();
}

class _AppVersionGateState extends ConsumerState<AppVersionGate> with WidgetsBindingObserver {
  bool _nudgeHidden = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadNudgeState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.invalidate(versionStatusProvider);
  }

  String get _today => DateTime.now().toIso8601String().substring(0, 10);

  Future<void> _loadNudgeState() async {
    final last = await _store.read(key: _softKey);
    if (mounted) setState(() => _nudgeHidden = last == _today);
  }

  Future<void> _dismissNudge() async {
    await _store.write(key: _softKey, value: _today);
    if (mounted) setState(() => _nudgeHidden = true);
  }

  Future<void> _openStore(String? url) async {
    if (url == null || url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(versionStatusProvider).value ?? const VersionStatus();
    final forced = status.force || ref.watch(forceUpdateFlagProvider);
    final showNudge = !forced && status.soft && !_nudgeHidden;

    return Stack(
      children: [
        widget.child,
        if (showNudge)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.system_update_rounded, color: AppColors.navy),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('A new version of Synsyma is available.', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black)),
                      ),
                      TextButton(onPressed: _dismissNudge, child: const Text('Later')),
                      FilledButton(onPressed: () => _openStore(status.storeUrl), child: const Text('Update')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (forced)
          Positioned.fill(
            child: PopScope(
              canPop: false, // blocks the Android back button
              child: Material(
                color: Colors.white,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(color: const Color(0xFFE6F0FF), borderRadius: BorderRadius.circular(24)),
                          child: const Icon(Icons.system_update_rounded, size: 42, color: Color(0xFF0066FF)),
                        ),
                        const SizedBox(height: 24),
                        const Text('Update required', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.black)),
                        const SizedBox(height: 10),
                        Text(
                          (status.message?.isNotEmpty ?? false) ? status.message! : 'Please update Synsyma to keep booking and chatting. It only takes a moment.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15, height: 1.5, color: Color(0xFF4B5563)),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            onPressed: () => _openStore(status.storeUrl),
                            child: const Text('Update now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}