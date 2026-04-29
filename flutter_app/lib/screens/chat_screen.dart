import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final String otherUserId;

  const ChatScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
    required this.otherUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  String get _chatId {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ids = [uid, widget.otherUserId]..sort();
    return '${ids[0]}_${ids[1]}_${widget.deviceId}';
  }

  Future<void> _initChat() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(_chatId);
    final doc = await chatRef.get();
    if (!doc.exists) {
      await chatRef.set({
        'deviceId': widget.deviceId,
        'deviceName': widget.deviceName,
        'participants': [uid, widget.otherUserId],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _sendMessage() async {
  final text = _messageController.text.trim();
  if (text.isEmpty) return;

  final uid = FirebaseAuth.instance.currentUser!.uid;
  final chatRef = FirebaseFirestore.instance.collection('chats').doc(_chatId);

  // Chat aanmaken als hij nog niet bestaat
  final doc = await chatRef.get();
  if (!doc.exists) {
    await chatRef.set({
      'deviceId': widget.deviceId,
      'deviceName': widget.deviceName,
      'participants': [uid, widget.otherUserId],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  await chatRef.collection('messages').add({
    'text': text,
    'senderId': uid,
    'timestamp': FieldValue.serverTimestamp(),
  });

  _messageController.clear();
  Future.delayed(const Duration(milliseconds: 300), () {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  });
}


  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: Text('Chat · ${widget.deviceName}')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(_chatId)
                  .collection('messages')
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Nog geen berichten.'));
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index].data() as Map<String, dynamic>;
                    final isMe = msg['senderId'] == uid;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue[400] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          msg['text'] ?? '',
                          style: TextStyle(color: isMe ? Colors.white : Colors.black),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Typ een bericht...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send, color: Colors.blue),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}