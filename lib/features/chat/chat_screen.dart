import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/sub_page.dart';
import 'chat_controller.dart';
import 'chat_models.dart';
import 'chat_presence.dart';
import 'chat_widgets.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with WidgetsBindingObserver {
  final _scroll = ScrollController();
  final _picker = ImagePicker();
  late final ChatThreadController _thread;

  @override
  void initState() {
    super.initState();
    ChatPresence.isOpen = true;
    WidgetsBinding.instance.addObserver(this);
    _thread = ref.read(chatThreadProvider.notifier);
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _thread.open());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _thread.stop();
    ChatPresence.isOpen = false;
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _thread.setActive(state == AppLifecycleState.resumed);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    if (p.pixels >= p.maxScrollExtent - 240) _thread.loadOlder();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;

      if (bytes.length > 5 * 1024 * 1024) {
        showToast(context, 'That photo is too large. Choose a smaller one.');
        return;
      }

      final caption = await showImagePreview(context, bytes);
      if (caption == null) return;

      final name = file.name.contains('.') ? file.name : '${file.name}.jpg';
      await _thread.sendImage(bytes, name, caption: caption);
    } on PlatformException {
      if (mounted) showToast(context, 'Could not open the photo picker.');
    }
  }

  void _openImage(ChatMessage m) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ImageViewerPage(bytes: m.localImage, url: m.attachment?.url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(chatThreadProvider);

    // Follow new messages, unless the person has scrolled up to read older ones.
    ref.listen(
      chatThreadProvider.select((s) => s.messages.isEmpty ? null : s.messages.last.id),
      (prev, next) {
        if (prev == null || next == null || !_scroll.hasClients) return;
        final last = ref.read(chatThreadProvider).messages.last;
        if (last.isMine || _scroll.offset < 160) {
          _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      },
    );

    final inset = MediaQuery.paddingOf(context).top;
    final extraTop = inset < 44 ? 44 - inset : 0.0; // browsers have no status bar

    return Scaffold(
      backgroundColor: AppColors.authBg,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              _Header(topPadding: inset + extraTop),
              if (st.offline) const _OfflineStrip(),
              Expanded(child: _body(st)),
              ChatInputBar(
                onSend: _thread.sendText,
                onGallery: () => _pick(ImageSource.gallery),
                onCamera: () => _pick(ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(ChatThreadState st) {
    final messages = st.messages;

    if (st.loading && messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (st.error != null && messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Couldn’t load your messages.', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                st.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 14),
              OutlinedButton(onPressed: _thread.open, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    if (messages.isEmpty) return const _EmptyChat();

    // The list is upside down (newest first), so new messages appear at the
    // bottom and older ones load above without the view jumping.
    final list = messages.reversed.toList();

    ChatMessage? seen;
    for (final m in list) {
      if (m.isMine && m.status == MessageStatus.sent && m.readAt != null) {
        seen = m;
        break;
      }
    }

    return ListView.builder(
      controller: _scroll,
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      itemCount: list.length + (st.loadingOlder ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= list.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2))),
          );
        }

        final m = list[i];
        final newer = i > 0 ? list[i - 1] : null;
        final older = i + 1 < list.length ? list[i + 1] : null;

        final newDay = older == null || !sameDay(older.createdAt, m.createdAt);
        final first = newDay ||
            older.isMine != m.isMine ||
            m.createdAt.difference(older.createdAt).inMinutes >= 5;
        final last = newer == null ||
            newer.isMine != m.isMine ||
            !sameDay(newer.createdAt, m.createdAt) ||
            newer.createdAt.difference(m.createdAt).inMinutes >= 5;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (newDay) DayChip(dayLabel(m.createdAt)),
            MessageBubble(
              message: m,
              firstInGroup: first,
              lastInGroup: last,
              showSeen: seen != null && m.id == seen.id,
              onRetry: () => _thread.retry(m.clientId!),
              onDiscard: () => _thread.discard(m.clientId!),
              onOpenImage: () => _openImage(m),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.topPadding});
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(8, topPadding + 8, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.chevron_left_rounded, size: 30, color: AppColors.navy),
            onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
          ),
          const ChatAvatar(size: 48),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Synsyma Admin',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black),
                ),
                SizedBox(height: 2),
                Text('Support team', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineStrip extends StatelessWidget {
  const _OfflineStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF1D6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: const Text(
        'Can’t reach the server. Trying again...',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: Color(0xFF7A4B00)),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChatAvatar(size: 76),
            SizedBox(height: 18),
            Text('Start a conversation', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.black)),
            SizedBox(height: 6),
            Text(
              'Ask about a booking, a service or your account. Our team will reply here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}
