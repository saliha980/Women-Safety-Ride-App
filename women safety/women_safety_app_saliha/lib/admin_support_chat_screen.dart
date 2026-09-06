import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminSupportChatListScreen extends StatelessWidget {
  const AdminSupportChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.grey.shade100,
            child: const TabBar(
              labelColor: Color(0xFFC2185B),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color(0xFFC2185B),
              tabs: [
                Tab(icon: Icon(Icons.chat_bubble_outline), text: "Live Chats"),
                Tab(icon: Icon(Icons.mark_email_unread_outlined), text: "Admin Emails"),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _LiveChatListSection(),
                _AdminEmailInboxSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveChatListSection extends StatelessWidget {
  const _LiveChatListSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('support_chats')
          .orderBy('lastUpdated', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No live support chats available."));
        }

        var chats = snapshot.data!.docs;

        return ListView.builder(
          itemCount: chats.length,
          itemBuilder: (context, index) {
            var chat = chats[index].data() as Map<String, dynamic>;
            String userId = chat['userId'] ?? chats[index].id;
            String userEmail = chat['userEmail'] ?? 'User';
            String lastMessage = chat['lastMessage'] ?? '';
            bool unread = chat['unreadByAdmin'] ?? false;

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFC2185B),
                child: Text(userEmail.isNotEmpty ? userEmail[0].toUpperCase() : "U", style: const TextStyle(color: Colors.white)),
              ),
              title: Text(userEmail, style: TextStyle(fontWeight: unread ? FontWeight.bold : FontWeight.normal)),
              subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: unread
                  ? const CircleAvatar(radius: 6, backgroundColor: Colors.red)
                  : null,
              onTap: () {
                FirebaseFirestore.instance.collection('support_chats').doc(userId).update({'unreadByAdmin': false});

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminSupportChatDetailScreen(
                      userId: userId,
                      userEmail: userEmail,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _AdminEmailInboxSection extends StatelessWidget {
  const _AdminEmailInboxSection();

  void _deleteEmail(BuildContext context, String docId) async {
    await FirebaseFirestore.instance.collection('support_emails').doc(docId).delete();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email entry deleted.")),
      );
    }
  }

  void _viewEmailDetails(BuildContext context, Map<String, dynamic> emailData, String docId) {
    FirebaseFirestore.instance.collection('support_emails').doc(docId).update({'status': 'Read'});

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(emailData['subject'] ?? "No Subject"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("From: ${emailData['senderEmail'] ?? 'Unknown'}", style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("To: ${emailData['adminEmail'] ?? 'Admin'}", style: const TextStyle(color: Colors.grey)),
              const Divider(),
              const SizedBox(height: 8),
              Text(emailData['message'] ?? ""),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('support_emails')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No support emails received."));
        }

        var emailDocs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: emailDocs.length,
          padding: const EdgeInsets.all(12),
          itemBuilder: (context, index) {
            var doc = emailDocs[index];
            var emailData = doc.data() as Map<String, dynamic>;
            bool isUnread = (emailData['status'] ?? 'Unread') == 'Unread';

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                leading: Icon(
                  Icons.mail,
                  color: isUnread ? const Color(0xFFC2185B) : Colors.grey,
                ),
                title: Text(
                  emailData['subject'] ?? 'No Subject',
                  style: TextStyle(fontWeight: isUnread ? FontWeight.bold : FontWeight.normal),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("From: ${emailData['senderEmail'] ?? 'Unknown'}"),
                    Text(
                      emailData['message'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteEmail(context, doc.id),
                ),
                onTap: () => _viewEmailDetails(context, emailData, doc.id),
              ),
            );
          },
        );
      },
    );
  }
}

class AdminSupportChatDetailScreen extends StatefulWidget {
  final String userId;
  final String userEmail;

  const AdminSupportChatDetailScreen({super.key, required this.userId, required this.userEmail});

  @override
  State<AdminSupportChatDetailScreen> createState() => _AdminSupportChatDetailScreenState();
}

class _AdminSupportChatDetailScreenState extends State<AdminSupportChatDetailScreen> {
  final TextEditingController _replyController = TextEditingController();

  void _sendReply() async {
    String text = _replyController.text.trim();
    if (text.isEmpty) return;

    _replyController.clear();
    Timestamp now = Timestamp.now();

    DocumentReference chatDoc = FirebaseFirestore.instance.collection('support_chats').doc(widget.userId);

    await chatDoc.set({
      'lastMessage': text,
      'lastUpdated': now,
      'unreadByAdmin': false,
    }, SetOptions(merge: true));

    await chatDoc.collection('messages').add({
      'senderId': 'admin',
      'text': text,
      'timestamp': now,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Chat: ${widget.userEmail}"),
        backgroundColor: const Color(0xFFC2185B),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('support_chats')
                  .doc(widget.userId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                var docs = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    bool isAdminMsg = data['senderId'] == 'admin';

                    return Align(
                      alignment: isAdminMsg ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isAdminMsg ? const Color(0xFFC2185B) : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          data['text'] ?? '',
                          style: TextStyle(
                            color: isAdminMsg ? Colors.white : Colors.black87,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    decoration: const InputDecoration(
                      hintText: "Type reply...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(25))),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFFC2185B)),
                  onPressed: _sendReply,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}