import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final List<String> _notificationTypes = [
    'Database Update',
    'System Alert',
    'Security Notice',
    'Maintenance',
    'Data Change',
    'Configuration Update'
  ];
  bool _showOnlyUnread = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'System Messages & Alerts',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF003366),
        actions: [
          IconButton(
            icon: Icon(
              _showOnlyUnread ? Icons.mark_email_read : Icons.markunread,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _showOnlyUnread = !_showOnlyUnread;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {});
            },
          ),
        ],
      ),
      body: _buildNotificationsTab(),
    );
  }

  Widget _buildNotificationsTab() {
    if (_currentUser == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Authentication Required',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'Please sign in to view system alerts and database change notifications',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Statistics Card
        Card(
          margin: const EdgeInsets.all(16),
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .doc(_currentUser!.uid)
                  .collection('notifications')
                  .snapshots(),
              builder: (context, snapshot) {
                int total = 0;
                int unread = 0;
                int critical = 0;

                if (snapshot.hasData) {
                  total = snapshot.data!.docs.length;
                  unread = snapshot.data!.docs
                      .where((doc) =>
                          (doc.data() as Map<String, dynamic>)['read'] == false)
                      .length;
                  critical = snapshot.data!.docs
                      .where((doc) =>
                          (doc.data() as Map<String, dynamic>)['priority'] ==
                          'critical')
                      .length;
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      'Total',
                      total.toString(),
                      Icons.notifications,
                      const Color(0xFF003366),
                    ),
                    _buildStatItem(
                      'Unread',
                      unread.toString(),
                      Icons.markunread,
                      Colors.orange,
                    ),
                    _buildStatItem(
                      'Critical',
                      critical.toString(),
                      Icons.warning,
                      Colors.red,
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        // Filter Chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('All'),
                selected: !_showOnlyUnread,
                onSelected: (selected) {
                  setState(() {
                    _showOnlyUnread = !selected;
                  });
                },
              ),
              FilterChip(
                label: const Text('Unread'),
                selected: _showOnlyUnread,
                onSelected: (selected) {
                  setState(() {
                    _showOnlyUnread = selected;
                  });
                },
              ),
              ..._notificationTypes.map((type) => FilterChip(
                    label: Text(type),
                    selected: false,
                    onSelected: (_) {
                      // Filter by type if needed
                    },
                  )),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Notifications List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('users')
                .doc(_currentUser!.uid)
                .collection('notifications')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text(
                        'Error Loading Alerts',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              final notifications = snapshot.data?.docs ?? [];

              // Apply filter
              final filteredNotifications = notifications.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                if (_showOnlyUnread) {
                  return data['read'] == false;
                }
                return true;
              }).toList();

              if (filteredNotifications.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _showOnlyUnread
                            ? Icons.mark_email_read
                            : Icons.notifications_off_rounded,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _showOnlyUnread
                            ? 'No unread alerts'
                            : 'No system alerts',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _showOnlyUnread
                            ? 'All alerts have been read'
                            : 'You\'ll see system alerts and database change notifications here',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[500],
                        ),
                      ),
                      if (!_showOnlyUnread)
                        Padding(
                          padding: const EdgeInsets.only(top: 20.0),
                          child: ElevatedButton.icon(
                            onPressed: _createTestAlert,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF003366),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            icon: const Icon(Icons.add_alert),
                            label: const Text('Create Test Alert'),
                          ),
                        ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredNotifications.length,
                itemBuilder: (context, index) {
                  final doc = filteredNotifications[index];
                  final data = doc.data() as Map<String, dynamic>;

                  return _buildDatabaseAlertItem(
                    title: data['title'] ?? 'System Alert',
                    message: data['message'] ?? '',
                    timestamp: data['createdAt'],
                    isRead: data['read'] ?? false,
                    type: data['type'] ?? 'general',
                    priority: data['priority'] ?? 'normal',
                    collection: data['collection'] ?? '',
                    documentId: data['documentId'] ?? '',
                    changes: data['changes'] ?? {},
                    onTap: () {
                      _markAsRead(doc.reference);
                      _showAlertDetails(data);
                    },
                    onDelete: () {
                      _deleteAlert(doc.reference);
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildDatabaseAlertItem({
    required String title,
    required String message,
    required dynamic timestamp,
    required bool isRead,
    required String type,
    required String priority,
    required String collection,
    required String documentId,
    required Map<String, dynamic> changes,
    required VoidCallback onTap,
    required VoidCallback onDelete,
  }) {
    Color priorityColor;
    IconData priorityIcon;

    switch (priority) {
      case 'critical':
        priorityColor = Colors.red;
        priorityIcon = Icons.warning;
        break;
      case 'high':
        priorityColor = Colors.orange;
        priorityIcon = Icons.error_outline;
        break;
      case 'medium':
        priorityColor = Colors.blue;
        priorityIcon = Icons.info_outline;
        break;
      default:
        priorityColor = Colors.grey;
        priorityIcon = Icons.notifications;
    }

    IconData typeIcon;
    Color typeColor;

    switch (type.toLowerCase()) {
      case 'database update':
        typeIcon = Icons.storage;
        typeColor = Colors.purple;
        break;
      case 'system alert':
        typeIcon = Icons.system_update;
        typeColor = Colors.blue;
        break;
      case 'security notice':
        typeIcon = Icons.security;
        typeColor = Colors.red;
        break;
      case 'maintenance':
        typeIcon = Icons.engineering;
        typeColor = Colors.orange;
        break;
      case 'data change':
        typeIcon = Icons.edit;
        typeColor = Colors.green;
        break;
      case 'configuration update':
        typeIcon = Icons.settings;
        typeColor = Colors.purple;
        break;
      default:
        typeIcon = Icons.notifications;
        typeColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isRead ? 1 : 2,
      color: isRead ? Colors.white : priorityColor.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isRead ? Colors.grey.shade200 : priorityColor.withOpacity(0.3),
          width: isRead ? 1 : 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(priorityIcon, color: priorityColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isRead ? Colors.grey[800] : priorityColor,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!isRead)
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(typeIcon, size: 14, color: typeColor),
                            const SizedBox(width: 4),
                            Text(
                              type,
                              style: TextStyle(
                                fontSize: 12,
                                color: typeColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (collection.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  collection,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') onDelete();
                      if (value == 'mark_read' && !isRead) onTap();
                    },
                    itemBuilder: (context) => [
                      if (!isRead)
                        const PopupMenuItem(
                          value: 'mark_read',
                          child: ListTile(
                            leading: Icon(Icons.check, size: 20),
                            title: Text('Mark as read'),
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading:
                              Icon(Icons.delete, size: 20, color: Colors.red),
                          title: Text('Delete'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (changes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Database Changes:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      ...changes.entries.map((entry) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Text(
                                  '${entry.key}: ',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  entry.value.toString(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatTimestamp(timestamp),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (documentId.isNotEmpty)
                    Text(
                      'ID: ${documentId.substring(0, min(8, documentId.length))}...',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontFamily: 'monospace',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Recently';
    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is DateTime) {
        date = timestamp;
      } else {
        return 'Recently';
      }

      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} min ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} hours ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday ${DateFormat('HH:mm').format(date)}';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return DateFormat('MMM dd, yyyy HH:mm').format(date);
      }
    } catch (e) {
      return 'Recently';
    }
  }

  int min(int a, int b) => a < b ? a : b;

  Future<void> _markAsRead(DocumentReference ref) async {
    await ref.update({'read': true});
  }

  Future<void> _deleteAlert(DocumentReference ref) async {
    await ref.delete();
  }

  void _showAlertDetails(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['title'] ?? 'Alert Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data['message'] ?? '',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              if (data['collection'] != null)
                ListTile(
                  leading: const Icon(Icons.collections_bookmark),
                  title: const Text('Collection'),
                  subtitle: Text(data['collection']),
                ),
              if (data['documentId'] != null)
                ListTile(
                  leading: const Icon(Icons.description),
                  title: const Text('Document ID'),
                  subtitle: Text(data['documentId']),
                ),
              if (data['changes'] != null)
                ...(data['changes'] as Map<String, dynamic>).entries.map(
                      (entry) => ListTile(
                        leading: const Icon(Icons.edit),
                        title: Text(entry.key),
                        subtitle: Text(entry.value.toString()),
                      ),
                    ),
              if (data['metadata'] != null)
                ...(data['metadata'] as Map<String, dynamic>).entries.map(
                      (entry) => ListTile(
                        leading: const Icon(Icons.info),
                        title: Text(entry.key),
                        subtitle: Text(entry.value.toString()),
                      ),
                    ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _createTestAlert() async {
    if (_currentUser == null) return;

    final notificationId = DateTime.now().millisecondsSinceEpoch.toString();

    await _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('notifications')
        .doc(notificationId)
        .set({
      'title': 'Test Database Alert',
      'message':
          'This is a test notification to demonstrate database change alerts',
      'type': 'Database Update',
      'priority': 'medium',
      'read': false,
      'collection': 'users',
      'documentId': _currentUser!.uid,
      'changes': {
        'lastLogin': DateTime.now().toIso8601String(),
        'status': 'active'
      },
      'createdAt': FieldValue.serverTimestamp(),
      'metadata': {'source': 'test', 'trigger': 'manual', 'version': '1.0.0'}
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test alert created successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
