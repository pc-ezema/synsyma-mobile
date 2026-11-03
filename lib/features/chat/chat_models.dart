import 'dart:typed_data';

enum MessageStatus { sent, sending, failed }

class ChatAttachment {
  const ChatAttachment({required this.url, this.name, this.mime});

  final String url;
  final String? name;
  final String? mime;

  factory ChatAttachment.fromJson(Map<String, dynamic> j) => ChatAttachment(
        url: j['url'].toString(),
        name: j['name']?.toString(),
        mime: j['mime']?.toString(),
      );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.body,
    required this.isMine,
    required this.createdAt,
    this.clientId,
    this.attachment,
    this.readAt,
    this.status = MessageStatus.sent,
    this.localImage,
    this.localName,
    this.error,
  });

  final String id;
  final String? clientId;
  final String? body;
  final bool isMine;
  final DateTime createdAt;
  final ChatAttachment? attachment;
  final DateTime? readAt;
  final MessageStatus status;
  final Uint8List? localImage; // the photo while it is still uploading
  final String? localName;
  final String? error;

  bool get hasImage => attachment != null || localImage != null;

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    final att = j['attachment'];
    final body = j['body']?.toString();

    return ChatMessage(
      id: j['id'].toString(),
      clientId: j['client_id']?.toString(),
      body: (body == null || body.isEmpty) ? null : body,
      isMine: j['is_mine'] == true,
      createdAt: DateTime.parse(j['created_at'].toString()).toLocal(),
      attachment: att is Map ? ChatAttachment.fromJson(Map<String, dynamic>.from(att)) : null,
      readAt: j['read_at'] == null ? null : DateTime.tryParse(j['read_at'].toString())?.toLocal(),
    );
  }

  /// A message that is on screen before the server has confirmed it.
  factory ChatMessage.pending({
    required String clientId,
    String? body,
    Uint8List? image,
    String? filename,
  }) =>
      ChatMessage(
        id: 'local-$clientId',
        clientId: clientId,
        body: body,
        isMine: true,
        createdAt: DateTime.now(),
        status: MessageStatus.sending,
        localImage: image,
        localName: filename,
      );

  ChatMessage copyWith({MessageStatus? status, String? error, bool clearError = false}) => ChatMessage(
        id: id,
        clientId: clientId,
        body: body,
        isMine: isMine,
        createdAt: createdAt,
        attachment: attachment,
        readAt: readAt,
        status: status ?? this.status,
        localImage: localImage,
        localName: localName,
        error: clearError ? null : (error ?? this.error),
      );
}

class ChatSummary {
  const ChatSummary({this.id, this.preview, this.lastAt, this.lastFromAdmin = false, this.unread = 0});

  final String? id;
  final String? preview;
  final DateTime? lastAt;
  final bool lastFromAdmin;
  final int unread;

  static const empty = ChatSummary();

  factory ChatSummary.fromJson(Map<String, dynamic> j) => ChatSummary(
        id: j['id']?.toString(),
        preview: j['last_message_preview']?.toString(),
        lastAt: j['last_message_at'] == null ? null : DateTime.tryParse(j['last_message_at'].toString())?.toLocal(),
        lastFromAdmin: j['last_message_sender'] == 'admin',
        unread: (j['unread_count'] as num?)?.toInt() ?? 0,
      );
}
