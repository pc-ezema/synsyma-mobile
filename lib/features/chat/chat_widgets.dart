import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/sub_page.dart';
import 'chat_models.dart';
import 'chat_repository.dart';

const _muted = Color(0xFF6B7280);

/// The Synsyma mark on a dark circle, used for the admin everywhere in chat.
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.14),
      decoration: const BoxDecoration(color: AppColors.logoTile, shape: BoxShape.circle),
      child: Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(Icons.support_agent, size: size * 0.5, color: Colors.white),
      ),
    );
  }
}

class DayChip extends StatelessWidget {
  const DayChip(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 22),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
          child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.navy)),
        ),
      ),
    );
  }
}

/// A photo that needs the sign-in token to download.
class AuthImage extends ConsumerStatefulWidget {
  const AuthImage({super.key, required this.url, this.width, this.height, this.fit = BoxFit.cover});

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  ConsumerState<AuthImage> createState() => _AuthImageState();
}

class _AuthImageState extends ConsumerState<AuthImage> {
  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _bytes = ChatImageCache.get(widget.url);
    if (_bytes == null) _load();
  }

  Future<void> _load() async {
    _failed = false;
    try {
      final bytes = await ref.read(chatRepositoryProvider).imageBytes(widget.url);
      ChatImageCache.put(widget.url, bytes);
      if (mounted) setState(() => _bytes = bytes);
    } on ApiError {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null) {
      return Image.memory(bytes, width: widget.width, height: widget.height, fit: widget.fit, gaplessPlayback: true);
    }

    return SizedBox(
      width: widget.width ?? 240,
      height: widget.height ?? 240,
      child: ColoredBox(
        color: const Color(0xFFDDE3EC),
        child: Center(
          child: _failed
              ? IconButton(
                  tooltip: 'Try again',
                  icon: const Icon(Icons.refresh_rounded, color: _muted),
                  onPressed: () {
                    setState(() => _failed = false);
                    _load();
                  },
                )
              : const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2)),
        ),
      ),
    );
  }
}

class ImageViewerPage extends StatelessWidget {
  const ImageViewerPage({super.key, this.bytes, this.url});

  final Uint8List? bytes;
  final String? url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white, elevation: 0),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: bytes != null ? Image.memory(bytes!) : AuthImage(url: url!, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

/// One message, with the admin's name and avatar on the first message of a run.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.firstInGroup,
    required this.lastInGroup,
    required this.showSeen,
    required this.onRetry,
    required this.onDiscard,
    required this.onOpenImage,
  });

  final ChatMessage message;
  final bool firstInGroup;
  final bool lastInGroup;
  final bool showSeen;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;
  final VoidCallback onOpenImage;

  static const _adminIndent = 62.0;
  static const _imageSize = 200.0;

  @override
  Widget build(BuildContext context) {
    final mine = message.isMine;
    final maxWidth = min(MediaQuery.sizeOf(context).width, 480.0) * 0.72;
    final meta = _meta();

    final bubble = GestureDetector(
      onLongPress: message.body == null
          ? null
          : () {
              Clipboard.setData(ClipboardData(text: message.body!));
              showToast(context, 'Message copied');
            },
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: message.hasImage
            ? const EdgeInsets.all(4)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: mine ? AppColors.chatSent : AppColors.chatReceived,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.hasImage) _image(),
            if (message.body != null)
              Padding(
                padding: message.hasImage ? const EdgeInsets.fromLTRB(10, 8, 10, 6) : EdgeInsets.zero,
                child: Text(
                  message.body!,
                  style: TextStyle(fontSize: 14, height: 1.4, color: mine ? Colors.white : AppColors.navy),
                ),
              ),
          ],
        ),
      ),
    );

    final bottom = lastInGroup ? 20.0 : 6.0;

    if (mine) {
      return Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            bubble,
            if (meta != null) Padding(padding: const EdgeInsets.only(top: 6), child: meta),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (firstInGroup)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  ChatAvatar(size: 40),
                  SizedBox(width: 12),
                  Text(
                    'Synsyma Admin',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black),
                  ),
                ],
              ),
            ),
          Padding(padding: const EdgeInsets.only(left: _adminIndent), child: bubble),
          if (meta != null)
            Padding(padding: const EdgeInsets.only(left: _adminIndent, top: 6), child: meta),
        ],
      ),
    );
  }

  Widget _image() {
    final radius = BorderRadius.circular(11);

    if (message.localImage != null) {
      return ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Image.memory(message.localImage!, width: _imageSize, height: _imageSize, fit: BoxFit.cover),
            if (message.status == MessageStatus.sending)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x66000000),
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onOpenImage,
      child: ClipRRect(
        borderRadius: radius,
        child: AuthImage(url: message.attachment!.url, width: _imageSize, height: _imageSize),
      ),
    );
  }

  Widget? _meta() {
    const style = TextStyle(fontSize: 11, color: _muted);

    if (message.status == MessageStatus.failed) {
      return Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 14, color: AppColors.danger),
          const SizedBox(width: 4),
          const Text('Not sent', style: TextStyle(fontSize: 12, color: AppColors.danger)),
          _LinkText('Retry', onRetry),
          _LinkText('Delete', onDiscard),
        ],
      );
    }

    if (message.status == MessageStatus.sending) {
      return const Text('Sending...', style: style);
    }

    if (!lastInGroup) return null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(clockTime(message.createdAt), style: style),
        if (showSeen) ...[
          const SizedBox(width: 8),
          const Text('Seen', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.chatSent)),
        ],
      ],
    );
  }
}

class _LinkText extends StatelessWidget {
  const _LinkText(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.blueDark),
        ),
      ),
    );
  }
}

/// Paperclip, message field, then a camera button that turns into Send once you type.
class ChatInputBar extends StatefulWidget {
  const ChatInputBar({super.key, required this.onSend, required this.onGallery, required this.onCamera});

  final ValueChanged<String> onSend;
  final VoidCallback onGallery;
  final VoidCallback onCamera;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _text = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(() {
      final has = _text.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _text.text.trim();
    if (value.isEmpty) return;
    widget.onSend(value);
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 14, offset: Offset(0, -3))],
      ),
      padding: EdgeInsets.fromLTRB(6, 10, 12, 10 + MediaQuery.paddingOf(context).bottom),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            tooltip: 'Attach a photo',
            onPressed: widget.onGallery,
            icon: const Icon(Icons.attach_file_rounded, size: 26, color: AppColors.navy),
          ),
          Expanded(
            child: TextField(
              controller: _text,
              minLines: 1,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [LengthLimitingTextInputFormatter(4000)],
              style: const TextStyle(fontSize: 14, color: AppColors.navy),
              decoration: InputDecoration(
                hintText: 'Write your message',
                hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9EA3B0)),
                filled: true,
                fillColor: AppColors.authBg,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: _hasText
                ? Padding(
                    key: const ValueKey('send'),
                    padding: const EdgeInsets.only(bottom: 1),
                    child: Semantics(
                      button: true,
                      label: 'Send message',
                      child: Material(
                        color: AppColors.chatSent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _submit,
                          child: const SizedBox(
                            width: 46,
                            height: 46,
                            child: Icon(Icons.send_rounded, size: 21, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  )
                : IconButton(
                    key: const ValueKey('camera'),
                    tooltip: 'Take a photo',
                    onPressed: widget.onCamera,
                    icon: const Icon(Icons.photo_camera_outlined, size: 26, color: AppColors.navy),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Shows the chosen photo with an optional caption. Returns the caption, or null if cancelled.
Future<String?> showImagePreview(BuildContext context, Uint8List bytes) {
  final caption = TextEditingController();

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    constraints: const BoxConstraints(maxWidth: 480),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.42),
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: caption,
              maxLength: 500,
              maxLines: 2,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              decoration: InputDecoration(
                hintText: 'Add a caption (optional)',
                hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9EA3B0)),
                filled: true,
                fillColor: AppColors.authBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: AppColors.blueDark,
                      side: const BorderSide(color: AppColors.blueDark),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, caption.text),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: AppColors.chatSent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Send'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  ).whenComplete(caption.dispose);
}
