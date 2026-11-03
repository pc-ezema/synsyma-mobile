import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_error.dart';
import '../auth/auth_controller.dart';
import 'chat_models.dart';
import 'chat_repository.dart';

/// A random v4 id. The server uses it to ignore a message that was sent twice.
String newClientId() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

// ---------------------------------------------------------------------------
// Inbox row + unread badge
// ---------------------------------------------------------------------------

final chatSummaryProvider = AsyncNotifierProvider<ChatSummaryController, ChatSummary>(ChatSummaryController.new);

class ChatSummaryController extends AsyncNotifier<ChatSummary> {
  @override
  Future<ChatSummary> build() async {
    final status = ref.watch(authProvider.select((s) => s.status));
    if (status != AuthStatus.signedIn) return ChatSummary.empty;

    // Refresh the badge every 45 seconds. Push notifications cover the rest.
    final timer = Timer(const Duration(seconds: 45), () => ref.invalidateSelf());
    ref.onDispose(timer.cancel);

    return ref.read(chatRepositoryProvider).summary();
  }
}

// ---------------------------------------------------------------------------
// The conversation itself
// ---------------------------------------------------------------------------

class ChatThreadState {
  const ChatThreadState({
    this.messages = const [],
    this.hasMore = false,
    this.loading = false,
    this.loadingOlder = false,
    this.error,
    this.offline = false,
  });

  final List<ChatMessage> messages; // oldest first
  final bool hasMore; // older messages exist on the server
  final bool loading;
  final bool loadingOlder;
  final String? error;
  final bool offline;

  ChatThreadState copyWith({
    List<ChatMessage>? messages,
    bool? hasMore,
    bool? loading,
    bool? loadingOlder,
    String? error,
    bool clearError = false,
    bool? offline,
  }) =>
      ChatThreadState(
        messages: messages ?? this.messages,
        hasMore: hasMore ?? this.hasMore,
        loading: loading ?? this.loading,
        loadingOlder: loadingOlder ?? this.loadingOlder,
        error: clearError ? null : (error ?? this.error),
        offline: offline ?? this.offline,
      );
}

final chatThreadProvider = NotifierProvider<ChatThreadController, ChatThreadState>(ChatThreadController.new);

class ChatThreadController extends Notifier<ChatThreadState> {
  Timer? _timer;
  bool _active = true;
  bool _polling = false;
  int _failures = 0;

  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  @override
  ChatThreadState build() {
    ref.watch(authProvider.select((s) => s.status)); // a new login starts clean
    ref.onDispose(() => _timer?.cancel());
    return const ChatThreadState();
  }

  /// Load the latest messages and start checking for new ones every 4 seconds.
  Future<void> open() async {
    _timer?.cancel();
    _failures = 0;
    state = state.copyWith(loading: state.messages.isEmpty, clearError: true);

    try {
      final first = state.messages.isEmpty;
      final page = await _repo.messages();
      state = state.copyWith(
        messages: _merge(state.messages, page.items),
        hasMore: first ? page.hasMore : state.hasMore,
        loading: false,
        offline: false,
      );
      unawaited(markRead());
    } on ApiError catch (e) {
      state = state.messages.isEmpty
          ? state.copyWith(loading: false, error: e.message, offline: true)
          : state.copyWith(loading: false, offline: true);
    }

    _timer = Timer.periodic(const Duration(seconds: 4), (_) => poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Pause while the app is in the background, catch up when it returns.
  void setActive(bool active) {
    _active = active;
    if (active) poll();
  }

  Future<void> poll() async {
    if (!_active || _polling) return;
    _polling = true;

    try {
      var page = await _repo.messages(after: _lastServerId());
      var found = page.items;

      var guard = 0;
      while (page.hasMore && found.isNotEmpty && guard++ < 5) {
        page = await _repo.messages(after: found.last.id);
        found = [...found, ...page.items];
      }

      _failures = 0;

      if (found.isNotEmpty) {
        state = state.copyWith(messages: _merge(state.messages, found), offline: false);
        if (found.any((m) => !m.isMine)) unawaited(markRead());
      } else if (state.offline) {
        state = state.copyWith(offline: false);
      }
    } on ApiError {
      if (++_failures >= 2 && !state.offline) state = state.copyWith(offline: true);
    } finally {
      _polling = false;
    }
  }

  Future<void> loadOlder() async {
    if (state.loadingOlder || !state.hasMore) return;

    final oldest = state.messages.where((m) => m.status == MessageStatus.sent).firstOrNull;
    if (oldest == null) return;

    state = state.copyWith(loadingOlder: true);
    try {
      final page = await _repo.messages(before: oldest.id);
      state = state.copyWith(
        messages: _merge(state.messages, page.items),
        hasMore: page.hasMore,
        loadingOlder: false,
      );
    } on ApiError {
      state = state.copyWith(loadingOlder: false);
    }
  }

  Future<void> sendText(String text) async {
    final body = text.trim();
    if (body.isEmpty) return;
    await _enqueue(ChatMessage.pending(clientId: newClientId(), body: body));
  }

  Future<void> sendImage(Uint8List bytes, String filename, {String? caption}) async {
    final text = caption?.trim();
    await _enqueue(ChatMessage.pending(
      clientId: newClientId(),
      body: (text == null || text.isEmpty) ? null : text,
      image: bytes,
      filename: filename,
    ));
  }

  Future<void> retry(String clientId) async {
    final failed = state.messages
        .where((m) => m.clientId == clientId && m.status == MessageStatus.failed)
        .firstOrNull;
    if (failed != null) await _deliver(failed);
  }

  void discard(String clientId) {
    state = state.copyWith(
      messages: state.messages
          .where((m) => m.clientId != clientId || m.status == MessageStatus.sent)
          .toList(),
    );
  }

  Future<void> markRead() async {
    try {
      await _repo.markRead();
      ref.invalidate(chatSummaryProvider);
    } on ApiError {
      // it is tried again with the next poll
    }
  }

  // ---- internals ----

  Future<void> _enqueue(ChatMessage message) async {
    state = state.copyWith(messages: [...state.messages, message]);
    await _deliver(message);
  }

  Future<void> _deliver(ChatMessage message) async {
    final clientId = message.clientId!;
    _update(clientId, (m) => m.copyWith(status: MessageStatus.sending, clearError: true));

    try {
      final sent = await _repo.send(
        body: message.body,
        image: message.localImage,
        filename: message.localName,
        clientId: clientId,
      );

      // Keep the photo we already have, so it does not flash while it reloads.
      if (message.localImage != null && sent.attachment != null) {
        ChatImageCache.put(sent.attachment!.url, message.localImage!);
      }

      state = state.copyWith(messages: _merge(state.messages, [sent]), offline: false);
      ref.invalidate(chatSummaryProvider);
    } on ApiError catch (e) {
      _update(clientId, (m) => m.copyWith(status: MessageStatus.failed, error: e.message));
    }
  }

  void _update(String clientId, ChatMessage Function(ChatMessage) change) {
    state = state.copyWith(
      messages: [
        for (final m in state.messages)
          (m.clientId == clientId && m.status != MessageStatus.sent) ? change(m) : m,
      ],
    );
  }

  String? _lastServerId() {
    for (final m in state.messages.reversed) {
      if (m.status == MessageStatus.sent) return m.id;
    }
    return null;
  }

  /// Server messages by id, plus our own unsent ones that the server has not echoed back yet.
  List<ChatMessage> _merge(List<ChatMessage> current, List<ChatMessage> incoming) {
    final byId = <String, ChatMessage>{
      for (final m in current.where((m) => m.status == MessageStatus.sent)) m.id: m,
    };
    for (final m in incoming) {
      byId[m.id] = m;
    }

    final echoed = incoming.map((m) => m.clientId).whereType<String>().toSet();
    final pending = current.where((m) => m.status != MessageStatus.sent && !echoed.contains(m.clientId));

    final all = [...byId.values, ...pending];
    all.sort((a, b) {
      final c = a.createdAt.compareTo(b.createdAt);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
    return all;
  }
}
