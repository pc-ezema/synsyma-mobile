import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/sub_page.dart';
import 'chat_controller.dart';
import 'chat_models.dart';
import 'chat_widgets.dart';

/// The Chat tab: your conversation with Synsyma support.
class ChatTab extends ConsumerStatefulWidget {
  const ChatTab({super.key});

  @override
  ConsumerState<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends ConsumerState<ChatTab> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(chatSummaryProvider);
    try {
      await ref.read(chatSummaryProvider.future);
    } catch (_) {
      // the list simply keeps what it had
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(chatSummaryProvider).value ?? ChatSummary.empty;

    final q = _query.trim().toLowerCase();
    final matches = q.isEmpty ||
        'synsyma admin'.contains(q) ||
        (summary.preview ?? '').toLowerCase().contains(q);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            children: [
              Row(
                children: [
                  const Text('Chat', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Notifications',
                    onPressed: () => showToast(context, 'No notifications yet.'),
                    icon: const Icon(Icons.notifications_rounded, size: 26, color: Color(0xFF4B5060)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 14, color: AppColors.navy),
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9EA3B0)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 26, color: Color(0xFF6B7280)),
                  filled: true,
                  fillColor: AppColors.authBg,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.fieldBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.fieldBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.blueDark, width: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (matches)
                _ConversationRow(summary: summary, onTap: () => context.push('/chat'))
              else
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text('No conversations found.', style: TextStyle(color: Color(0xFF6B7280))),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.summary, required this.onTap});

  final ChatSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasMessages = summary.preview != null && summary.preview!.isNotEmpty;
    final unread = summary.unread;

    final preview = !hasMessages
        ? 'Start a conversation'
        : (summary.lastFromAdmin ? summary.preview! : 'You: ${summary.preview!}');

    return Semantics(
      button: true,
      label: 'Conversation with Synsyma Admin${unread > 0 ? ', $unread unread' : ''}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              const ChatAvatar(size: 54),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Synsyma Admin',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400,
                        color: unread > 0 ? AppColors.navy : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (summary.lastAt != null)
                    Text(timeAgo(summary.lastAt!), style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  if (unread > 0) ...[
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.chatBadge,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}