class ChatMessage {
  final String id;
  final String uid;
  final String username;
  final String text;
  final int ts;

  ChatMessage({required this.id, required this.uid, required this.username, required this.text, required this.ts});

  factory ChatMessage.fromMap(String id, Map<dynamic, dynamic> m) {
    return ChatMessage(
      id: id,
      uid: m['uid'] as String? ?? '',
      username: m['username'] as String? ?? '',
      text: m['text'] as String? ?? '',
      ts: (m['ts'] is int) ? m['ts'] as int : (m['ts'] is double ? (m['ts'] as double).toInt() : 0),
    );
  }
}
