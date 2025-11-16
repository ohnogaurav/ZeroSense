import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';

import '../services/firebase_service.dart';
import '../models/chat_message.dart';
import '../models/game_state.dart';

class ChatPanel extends StatefulWidget {
  final String roomId;
  final String username;
  const ChatPanel({super.key, required this.roomId, required this.username});

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();

  List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    FirebaseDatabase.instance.ref('rooms/${widget.roomId}/chat').onValue.listen((ev) {
      final snap = ev.snapshot;
      if (!snap.exists) {
        setState(() => _messages = []);
        return;
      }
      final map = Map<String, dynamic>.from(snap.value as Map);
      final list = map.entries.map((e) {
        return ChatMessage.fromMap(e.key!, Map<String, dynamic>.from(e.value));
      }).toList();
      // sort ascending by ts
      list.sort((a, b) => a.ts.compareTo(b.ts));
      setState(() => _messages = list);
      // auto-scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final firebase = Provider.of<FirebaseService>(context, listen: false);
    await firebase.sendChatMessage(widget.roomId, widget.username, text);
    _ctrl.clear();
    // scroll after send
    await Future.delayed(const Duration(milliseconds: 80));
    if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseDatabase.instance.app.name; // dummy - we will check username equality for bubble side
    return Column(
      children: [
        Container(
          width: 48,
          height: 4,
          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            itemCount: _messages.length,
            itemBuilder: (ctx, i) {
              final m = _messages[i];
              final isMe = m.username == widget.username;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    if (!isMe) const SizedBox(width: 6),
                    Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.cyan.withOpacity(0.95) : Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isMe)
                            Text(m.username, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(m.text, style: TextStyle(color: isMe ? Colors.black : Colors.white, fontSize: 15)),
                        ],
                      ),
                    ),
                    if (isMe) const SizedBox(width: 6),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Message",
                  hintStyle: TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.02),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.send_rounded, color: Colors.cyan), onPressed: _send),
          ],
        ),
      ],
    );
  }
}
