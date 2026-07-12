import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

class LiveChatScreen extends StatefulWidget {
  final String? chatRoomId;
  final String? subject;

  const LiveChatScreen({
    super.key,
    this.chatRoomId,
    this.subject,
  });

  @override
  State<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends State<LiveChatScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  String? _chatRoomId;
  String? _agentId;
  String? _agentName;
  String? _currentUserId;
  String? _currentUserName;
  bool _isTyping = false;
  bool _isAgentTyping = false;
  bool _isConnected = false;
  bool _isUploading = false;
  List<Map<String, dynamic>> _messages = [];
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  StreamSubscription<DocumentSnapshot>? _agentSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserData().then((_) {
      _initializeChat();
      _startTypingListener();
    });
  }

  Future<void> _loadUserData() async {
    _currentUserId = await _getCurrentUserId();
    _currentUserName = await _getCurrentUserName();
  }

  Future<void> _initializeChat() async {
    try {
      if (widget.chatRoomId != null) {
        _chatRoomId = widget.chatRoomId;
        await _loadExistingChat();
      } else {
        await _createNewChatRoom();
      }

      _connectToChat();
    } catch (e) {
      _showError('Failed to initialize chat: $e');
    }
  }

  Future<void> _createNewChatRoom() async {
    try {
      final userId = _currentUserId!;
      final userName = _currentUserName!;
      final userEmail = await _getCurrentUserEmail();

      // Get available agent
      final agent = await _getAvailableAgent();
      if (agent == null) {
        _showError(
            'No agents available at the moment. Please try again later.');
        return;
      }

      _agentId = agent['id'];
      _agentName = agent['name'];

      // Create chat room
      final chatRoomData = {
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'agentId': _agentId,
        'agentName': _agentName,
        'subject': widget.subject ?? 'General Inquiry',
        'status': 'active',
        'priority': 'normal',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCount': 0,
        'userUnread': 0,
        'agentUnread': 1,
        'rating': null,
        'resolved': false,
        'tags': [],
      };

      final chatRoomRef =
          await _firestore.collection('chat_rooms').add(chatRoomData);

      _chatRoomId = chatRoomRef.id;

      // Send welcome message
      await _sendSystemMessage(
        'Welcome to Alpha Bank Support! You\'re now chatting with $_agentName.',
      );

      // Send auto-reply
      await Future.delayed(const Duration(seconds: 1));
      await _sendAgentMessage(
        'Hello! Thank you for contacting Alpha Bank support. How can I help you today?',
      );

      // Update agent's active chats count
      await _firestore.collection('chat_agents').doc(_agentId).update({
        'activeChats': FieldValue.increment(1),
        'lastActive': FieldValue.serverTimestamp(),
      });

      setState(() {
        _isConnected = true;
      });
    } catch (e) {
      _showError('Failed to create chat room: $e');
    }
  }

  Future<void> _loadExistingChat() async {
    try {
      final chatRoomDoc =
          await _firestore.collection('chat_rooms').doc(_chatRoomId).get();

      if (chatRoomDoc.exists) {
        final data = chatRoomDoc.data()!;
        _agentId = data['agentId'];
        _agentName = data['agentName'];

        // Update unread count
        await chatRoomDoc.reference.update({
          'userUnread': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          _isConnected = true;
        });
      } else {
        _showError('Chat room not found');
      }
    } catch (e) {
      _showError('Failed to load chat: $e');
    }
  }

  Future<Map<String, dynamic>?> _getAvailableAgent() async {
    try {
      final agentsSnapshot = await _firestore
          .collection('chat_agents')
          .where('available', isEqualTo: true)
          .where('status', isEqualTo: 'online')
          .orderBy('activeChats')
          .limit(1)
          .get();

      if (agentsSnapshot.docs.isNotEmpty) {
        return {
          'id': agentsSnapshot.docs.first.id,
          ...agentsSnapshot.docs.first.data(),
        };
      }
      return null;
    } catch (e) {
      print('Error getting agent: $e');
      return null;
    }
  }

  void _connectToChat() {
    if (_chatRoomId != null) {
      _listenForMessages();
      _listenForAgentStatus();
    }
  }

  void _listenForMessages() {
    _messagesSubscription = _firestore
        .collection('chat_rooms')
        .doc(_chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _messages = snapshot.docs.map((doc) => doc.data()).toList();
        });

        // Scroll to bottom
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  void _listenForAgentStatus() {
    if (_agentId != null) {
      _agentSubscription = _firestore
          .collection('chat_agents')
          .doc(_agentId)
          .snapshots()
          .listen((snapshot) {
        if (mounted && snapshot.exists) {
          final data = snapshot.data()!;
          setState(() {
            _isAgentTyping = data['isTyping'] ?? false;
          });
        }
      });
    }
  }

  void _startTypingListener() {
    _messageController.addListener(() {
      if (_messageController.text.isNotEmpty && !_isTyping) {
        _setTypingStatus(true);
      } else if (_messageController.text.isEmpty && _isTyping) {
        _setTypingStatus(false);
      }
    });
  }

  Future<void> _setTypingStatus(bool isTyping) async {
    if (_chatRoomId != null && mounted) {
      setState(() {
        _isTyping = isTyping;
      });

      // Update typing status in chat room
      await _firestore.collection('chat_rooms').doc(_chatRoomId).update({
        'userIsTyping': isTyping,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = _messageController.text.trim();
    _messageController.clear();
    await _setTypingStatus(false);

    try {
      await _firestore
          .collection('chat_rooms')
          .doc(_chatRoomId)
          .collection('messages')
          .add({
        'senderId': _currentUserId!,
        'senderName': _currentUserName!,
        'type': 'text',
        'content': message,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'status': 'sent',
      });

      // Update chat room last message
      await _firestore.collection('chat_rooms').doc(_chatRoomId).update({
        'lastMessage': message,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'agentUnread': FieldValue.increment(1),
      });
    } catch (e) {
      _showError('Failed to send message: $e');
    }
  }

  Future<void> _sendSystemMessage(String message) async {
    try {
      await _firestore
          .collection('chat_rooms')
          .doc(_chatRoomId)
          .collection('messages')
          .add({
        'senderId': 'system',
        'senderName': 'System',
        'type': 'system',
        'content': message,
        'timestamp': FieldValue.serverTimestamp(),
        'read': true,
        'status': 'sent',
      });
    } catch (e) {
      print('Error sending system message: $e');
    }
  }

  Future<void> _sendAgentMessage(String message) async {
    try {
      await _firestore
          .collection('chat_rooms')
          .doc(_chatRoomId)
          .collection('messages')
          .add({
        'senderId': _agentId,
        'senderName': _agentName,
        'type': 'text',
        'content': message,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'status': 'sent',
      });

      // Update chat room
      await _firestore.collection('chat_rooms').doc(_chatRoomId).update({
        'lastMessage': message,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'userUnread': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error sending agent message: $e');
    }
  }

  Future<void> _pickAndSendImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _isUploading = true;
        });

        // In a real app, you would upload to Firebase Storage
        // For now, we'll simulate with a local path
        await Future.delayed(const Duration(seconds: 1));

        await _firestore
            .collection('chat_rooms')
            .doc(_chatRoomId)
            .collection('messages')
            .add({
          'senderId': _currentUserId!,
          'senderName': _currentUserName!,
          'type': 'image',
          'content': 'image_uploaded',
          'filePath': image.path,
          'fileName': image.name,
          'fileSize': await image.length(),
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'status': 'sent',
        });

        setState(() {
          _isUploading = false;
        });

        _showSuccess('Image sent successfully');
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      _showError('Failed to send image: $e');
    }
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMe = message['senderId'] == _currentUserId;
    final isSystem = message['senderId'] == 'system';
    final timestamp = message['timestamp'] as Timestamp?;
    final time =
        timestamp != null ? DateFormat('HH:mm').format(timestamp.toDate()) : '';

    if (isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              message['content'],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 2),
                child: Text(
                  message['senderName'] ?? 'Agent',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF003366) : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message['type'] == 'image')
                    Column(
                      children: [
                        Container(
                          width: 200,
                          height: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey[300],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.image,
                              color: Colors.grey,
                              size: 40,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '📷 Image',
                          style: TextStyle(
                            color: isMe ? Colors.white70 : Colors.grey[700],
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      message['content'] ?? '',
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black,
                        fontSize: 16,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe ? Colors.white70 : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    if (_isAgentTyping) {
      return Container(
        margin: const EdgeInsets.only(left: 16, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 4),
              decoration: const BoxDecoration(
                color: Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 4),
              decoration: const BoxDecoration(
                color: Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox();
  }

  Future<String> _getCurrentUserId() async {
    // TODO: Implement based on your authentication system
    // Example: return FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    return 'user_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<String> _getCurrentUserName() async {
    // TODO: Implement based on your authentication system
    // Example: return FirebaseAuth.instance.currentUser?.displayName ?? 'User';
    return 'Current User';
  }

  Future<String> _getCurrentUserEmail() async {
    // TODO: Implement based on your authentication system
    // Example: return FirebaseAuth.instance.currentUser?.email ?? 'user@example.com';
    return 'user@example.com';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _endChat() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Chat'),
        content: const Text('Are you sure you want to end this chat?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _closeChatRoom();
              if (mounted) {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('End Chat'),
          ),
        ],
      ),
    );
  }

  Future<void> _closeChatRoom() async {
    try {
      await _sendSystemMessage('Chat ended by user.');

      await _firestore.collection('chat_rooms').doc(_chatRoomId).update({
        'status': 'closed',
        'closedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'resolved': true,
      });

      // Update agent's active chats count
      if (_agentId != null) {
        await _firestore.collection('chat_agents').doc(_agentId).update({
          'activeChats': FieldValue.increment(-1),
          'lastActive': FieldValue.serverTimestamp(),
        });
      }

      _showSuccess('Chat ended successfully');
    } catch (e) {
      _showError('Failed to end chat: $e');
    }
  }

  void _showCallOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.green),
              title: const Text('Voice Call'),
              subtitle: const Text('Call the support agent directly'),
              onTap: () {
                Navigator.pop(context);
                _showSnackBar('Voice call feature coming soon');
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.blue),
              title: const Text('Video Call'),
              subtitle: const Text('Face-to-face support'),
              onTap: () {
                Navigator.pop(context);
                _showSnackBar('Video call feature coming soon');
              },
            ),
            ListTile(
              leading: const Icon(Icons.screen_share, color: Colors.purple),
              title: const Text('Screen Share'),
              subtitle: const Text('Share your screen for technical support'),
              onTap: () {
                Navigator.pop(context);
                _showSnackBar('Screen share feature coming soon');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.download, color: Color(0xFF003366)),
              title: const Text('Download Chat Transcript'),
              onTap: () {
                Navigator.pop(context);
                _downloadTranscript();
              },
            ),
            ListTile(
              leading: const Icon(Icons.people, color: Color(0xFF003366)),
              title: const Text('Request Different Agent'),
              onTap: () {
                Navigator.pop(context);
                _requestDifferentAgent();
              },
            ),
            ListTile(
              leading: const Icon(Icons.report, color: Colors.red),
              title: const Text('Report Issue'),
              onTap: () {
                Navigator.pop(context);
                _reportIssue();
              },
            ),
            ListTile(
              leading: const Icon(Icons.star, color: Colors.orange),
              title: const Text('Rate this Chat'),
              onTap: () {
                Navigator.pop(context);
                _rateChat();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _downloadTranscript() {
    _showSnackBar('Chat transcript downloaded');
  }

  void _requestDifferentAgent() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Different Agent'),
        content: const Text(
            'Are you sure you want to request a different support agent?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSnackBar('Agent transfer requested');
            },
            child: const Text('Request'),
          ),
        ],
      ),
    );
  }

  void _reportIssue() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Issue'),
        content: const Text('Please describe the issue you experienced:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSnackBar('Issue reported. Thank you for your feedback.');
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _rateChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rate this Chat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How would you rate your chat experience?'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [1, 2, 3, 4, 5].map((star) {
                return IconButton(
                  icon: Icon(
                    Icons.star,
                    color: star <= 4 ? Colors.orange : Colors.grey,
                    size: 32,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _submitRating(star);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _submitRating(int rating) {
    _showSnackBar('Thank you for your $rating-star rating!');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_agentName ?? 'Live Chat'),
            const SizedBox(height: 2),
            Text(
              _isConnected ? 'Connected' : 'Connecting...',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF003366),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              _showCallOptions();
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              _showChatOptions();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection status
          if (!_isConnected)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.orange[100],
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Connecting to support agent...'),
                ],
              ),
            ),

          // Agent info card
          if (_isConnected && _agentName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[50],
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF003366),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '👩‍💼',
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _agentName!,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Support Agent • Online',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.verified, color: Colors.blue, size: 20),
                ],
              ),
            ),

          // Messages list
          Expanded(
            child: Container(
              color: Colors.grey[100],
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _messages.length) {
                          return _buildTypingIndicator();
                        }
                        return _buildMessageBubble(_messages[index]);
                      },
                    ),
                  ),

                  // Upload indicator
                  if (_isUploading)
                    const LinearProgressIndicator(
                      backgroundColor: Color(0xFF003366),
                    ),
                ],
              ),
            ),
          ),

          // Input area
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                // Attachment button
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: _pickAndSendImage,
                  color: const Color(0xFF003366),
                ),

                // Message input
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type your message...',
                        border: InputBorder.none,
                      ),
                      maxLines: 3,
                      minLines: 1,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),

                // Send button
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF003366),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _endChat,
        backgroundColor: Colors.red,
        child: const Icon(Icons.call_end, color: Colors.white),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messagesSubscription?.cancel();
    _agentSubscription?.cancel();
    super.dispose();
  }
}
