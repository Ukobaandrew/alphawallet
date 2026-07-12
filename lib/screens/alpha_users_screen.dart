import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'transaction_workflow_screen.dart' as workflow;
import 'dart:async';

class AlphaUsersScreen extends StatefulWidget {
  const AlphaUsersScreen({super.key});

  @override
  State<AlphaUsersScreen> createState() => _AlphaUsersScreenState();
}

class _AlphaUsersScreenState extends State<AlphaUsersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _recentRecipients = [];
  List<Map<String, dynamic>> _recentTransfers = [];
  List<Map<String, dynamic>> _alphaBankUsers = [];

  final bool _showOnlineOnly = false;
  final bool _showFavoritesOnly = false;
  bool _isSearching = false;
  bool _isLoadingSearch = false;
  bool _isLoadingData = true;

  String? _currentUserId;
  List<String> _userFavorites = [];

  StreamSubscription<QuerySnapshot>? _transactionsListener;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _initializeUser();
  }

  void _initializeUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
      await _loadUserData();
      _setupTransactionListener();
    }
  }

  Future<void> _loadUserData() async {
    if (_currentUserId == null) return;

    setState(() {
      _isLoadingData = true;
    });

    try {
      // Load user favorites
      await _loadUserFavorites();

      // Load recent recipients from user's recent_recipients collection
      await _loadRecentRecipients();

      // Load recent transfers from user's transactions
      await _loadRecentTransfers();

      // Load Alpha Bank users (users who have Alpha Bank as their bank)
      await _loadAlphaBankUsers();

      setState(() {
        _isLoadingData = false;
      });
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoadingData = false;
      });
    }
  }

  void _setupTransactionListener() {
    if (_currentUserId == null) return;

    // Listen for new transactions in real-time
    _transactionsListener = _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('transactions')
        .where('type', whereIn: ['transfer', 'withdrawal', 'send'])
        .where('status', isEqualTo: 'completed')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.docs.isNotEmpty && mounted) {
            // Refresh the data when new transactions are added
            _refreshData();
          }
        });
  }

  Future<void> _refreshData() async {
    if (_currentUserId == null) return;

    setState(() {
      _isLoadingData = true;
    });

    await Future.wait([
      _loadUserFavorites(),
      _loadRecentRecipients(),
      _loadRecentTransfers(),
      _loadAlphaBankUsers(),
    ]);

    setState(() {
      _isLoadingData = false;
    });
  }

  Future<void> _loadUserFavorites() async {
    if (_currentUserId == null) return;

    final favoritesRef = _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('alpha_user_favorites');

    final snapshot = await favoritesRef.get();

    setState(() {
      _userFavorites = snapshot.docs.map((doc) => doc.id).toList();
    });
  }

  Future<void> _loadRecentRecipients() async {
    if (_currentUserId == null) return;

    try {
      final recipientsRef = _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('recent_recipients')
          .orderBy('lastTransfer', descending: true)
          .limit(20);

      final snapshot = await recipientsRef.get();

      final List<Map<String, dynamic>> recipients = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final recipientId = data['id'] ?? doc.id;
        final accountNumber = data['account'] ?? data['accountNumber'] ?? 'N/A';

        // Handle last transfer time
        Timestamp lastTransfer = data['lastTransfer'] ?? Timestamp.now();

        // If lastTransfer is not set, try to get from transactions
        if (data['lastTransfer'] == null) {
          try {
            final recentTransaction = await _firestore
                .collection('users')
                .doc(_currentUserId)
                .collection('transactions')
                .where('recipientAccount', isEqualTo: accountNumber)
                .orderBy('timestamp', descending: true)
                .limit(1)
                .get();

            if (recentTransaction.docs.isNotEmpty) {
              lastTransfer = recentTransaction.docs.first.data()['timestamp']
                      as Timestamp? ??
                  Timestamp.now();
            }
          } catch (e) {
            print('Error fetching last transaction: $e');
          }
        }

        // Get total transfers and amount
        int totalTransfers = data['totalTransfers'] ?? 0;
        double totalAmount = (data['totalAmount'] ?? 0.0).toDouble();

        // If not available, calculate from transactions
        if (totalTransfers == 0) {
          try {
            final transactions = await _firestore
                .collection('users')
                .doc(_currentUserId)
                .collection('transactions')
                .where('recipientAccount', isEqualTo: accountNumber)
                .where('status', isEqualTo: 'completed')
                .get();

            totalTransfers = transactions.docs.length;
            totalAmount = transactions.docs.fold(0.0, (sum, doc) {
              final amount = (doc.data()['amount'] ?? 0.0).toDouble();
              return sum + (amount < 0 ? -amount : amount);
            });
          } catch (e) {
            print('Error calculating transfer totals: $e');
          }
        }

        recipients.add({
          'id': recipientId,
          'name': data['name'] ?? 'Unknown User',
          'account': accountNumber,
          'bank': data['bank'] ?? 'Alpha Bank',
          'avatar': _getInitials(data['name'] ?? 'UU'),
          'lastTransfer': lastTransfer,
          'totalTransfers': totalTransfers,
          'totalAmount': totalAmount,
          'isFavorite': data['isFavorite'] ?? false,
          'avatarColor': _getAvatarColor(recipientId),
          'type': 'recent',
        });
      }

      // Sort by lastTransfer
      recipients.sort((a, b) {
        final aTime = (a['lastTransfer'] as Timestamp).millisecondsSinceEpoch;
        final bTime = (b['lastTransfer'] as Timestamp).millisecondsSinceEpoch;
        return bTime.compareTo(aTime);
      });

      setState(() {
        _recentRecipients = recipients;
      });
    } catch (e) {
      print('Error loading recent recipients: $e');
    }
  }

  Future<void> _loadRecentTransfers() async {
    if (_currentUserId == null) return;

    try {
      final transactionsRef = _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('transactions')
          .where('type', whereIn: ['transfer', 'withdrawal', 'send'])
          .where('status', isEqualTo: 'completed')
          .orderBy('timestamp', descending: true)
          .limit(50);

      final snapshot = await transactionsRef.get();

      // Extract unique recipient accounts from transactions
      final Map<String, Map<String, dynamic>> uniqueTransfers = {};
      final Set<String> seenAccounts = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();

        // Skip if there's no recipient info
        if (!data.containsKey('to') && !data.containsKey('recipientName')) {
          continue;
        }

        final recipientName =
            data['recipientName'] ?? data['to'] ?? 'Unknown User';
        final recipientAccount =
            data['recipientAccount'] ?? data['toAccount'] ?? 'N/A';
        final bankName = data['bankName'] ?? data['bank'] ?? 'Alpha Bank';
        final amount = (data['amount'] ?? 0.0).toDouble();
        final timestamp = data['timestamp'] ?? Timestamp.now();

        // Skip invalid entries
        if (recipientAccount == 'N/A' ||
            recipientAccount.toString().isEmpty ||
            seenAccounts.contains(recipientAccount.toString())) {
          continue;
        }

        // Clean up recipient name
        String cleanedName = recipientName.toString();
        if (cleanedName.contains('to: ')) {
          cleanedName = cleanedName.replaceAll('to: ', '');
        }

        // Check if this is an Alpha Bank transfer
        final isAlpha = data['transactionType'] == 'Alpha Users' ||
            bankName.contains('Alpha') ||
            data['type'] == 'alpha_transfer';

        seenAccounts.add(recipientAccount.toString());

        uniqueTransfers[recipientAccount.toString()] = {
          'id': 'transfer_${doc.id}',
          'name': cleanedName,
          'account': recipientAccount.toString(),
          'bank': bankName,
          'lastTransfer': timestamp,
          'amount': amount < 0 ? -amount : amount, // Use positive amount
          'avatar': _getInitials(cleanedName),
          'avatarColor': _getAvatarColor(recipientAccount.toString()),
          'type': 'transfer',
          'isAlpha': isAlpha,
          'timestamp': timestamp,
          'transactionId': data['transactionId'] ?? doc.id,
        };
      }

      // Convert to list and sort by timestamp (most recent first)
      final List<Map<String, dynamic>> transfersList =
          uniqueTransfers.values.toList();
      transfersList.sort((a, b) {
        final aTime = (a['timestamp'] as Timestamp).millisecondsSinceEpoch;
        final bTime = (b['timestamp'] as Timestamp).millisecondsSinceEpoch;
        return bTime.compareTo(aTime);
      });

      setState(() {
        _recentTransfers =
            transfersList.take(15).toList(); // Limit to 15 most recent
      });
    } catch (e) {
      print('Error loading recent transfers: $e');
    }
  }

  Future<void> _loadAlphaBankUsers() async {
    try {
      // Get all Alpha Bank users from alpha_users collection
      final alphaUsersQuery = await _firestore
          .collection('alpha_users')
          .where('bank', isEqualTo: 'Alpha Bank')
          .limit(50)
          .get();

      final alphaUsers = alphaUsersQuery.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'userId': data['userId'],
          'name': data['name'] ?? 'Unknown User',
          'accountNumber': data['accountNumber'] ?? 'N/A',
          'email': data['email'] ?? 'No email',
          'phone': data['phone'] ?? '',
          'avatar': _getInitials(data['name'] ?? 'UU'),
          'avatarColor': _getAvatarColor(doc.id),
          'isFavorite': _userFavorites.contains(doc.id),
          'isOnline': data['isOnline'] ?? false,
          'lastActiveText': _getLastActiveText(data['lastActive']),
          'balance': data['balance'] ?? 0.0,
          'balanceFormatted': data['balanceFormatted'] ?? '\$0.00',
          'bank': data['bank'] ?? 'Alpha Bank',
          'role': 'alpha_user',
          'isVerified': true,
          'joinDate': data['joinDate'] ?? Timestamp.now(),
          'totalTransfers': data['totalTransfers'] ?? 0,
          'totalAmount': data['totalAmount'] ?? 0.0,
          'rating': data['rating'] ?? 0.0,
          'status': data['status'] ?? 'active',
        };
      }).toList();

      setState(() {
        _alphaBankUsers = alphaUsers;
      });
    } catch (e) {
      print('Error loading Alpha Bank users: $e');
    }
  }

  String _getLastActiveText(dynamic lastActive) {
    if (lastActive == null) return 'Unknown';

    if (lastActive is Timestamp) {
      final lastActiveTime = lastActive.toDate();
      final now = DateTime.now();
      final difference = now.difference(lastActiveTime);

      if (difference.inMinutes < 5) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
      if (difference.inHours < 24) return '${difference.inHours} hours ago';
      return '${difference.inDays} days ago';
    }
    return 'Recently active';
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults.clear();
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _isLoadingSearch = true;
    });

    _searchUsers(query);
  }

  Future<void> _searchUsers(String query) async {
    try {
      final Set<String> seenIds = {};
      final List<Map<String, dynamic>> allResults = [];

      // Search in users collection
      final usersQueries = [
        _firestore
            .collection('users')
            .where('accountNumber', isEqualTo: query)
            .limit(5)
            .get(),
        _firestore
            .collection('users')
            .where('name', isGreaterThanOrEqualTo: query)
            .where('name', isLessThanOrEqualTo: '$query\uf8ff')
            .limit(10)
            .get(),
        _firestore
            .collection('users')
            .where('email', isGreaterThanOrEqualTo: query)
            .where('email', isLessThanOrEqualTo: '$query\uf8ff')
            .limit(5)
            .get(),
        _firestore
            .collection('users')
            .where('phone', isGreaterThanOrEqualTo: query)
            .where('phone', isLessThanOrEqualTo: '$query\uf8ff')
            .limit(5)
            .get(),
      ];

      final userResults = await Future.wait(usersQueries);

      for (final result in userResults) {
        for (final doc in result.docs) {
          if (doc.id == _currentUserId) continue;

          if (!seenIds.contains(doc.id)) {
            seenIds.add(doc.id);
            final data = doc.data();

            allResults.add({
              'id': doc.id,
              'name': data['name'] ?? 'Unknown User',
              'email': data['email'] ?? 'No email',
              'accountNumber': data['accountNumber'] ?? 'N/A',
              'phone': data['phone'] ?? '',
              'avatar': _getInitials(data['name'] ?? 'UU'),
              'avatarColor': _getAvatarColor(doc.id),
              'isFavorite': _userFavorites.contains(doc.id),
              'isOnline': false,
              'lastActiveText': 'Recently active',
              'balance': data['balance'] ?? 0.0,
              'bank': 'Alpha Bank',
              'role': data['role'] ?? 'user',
              'isVerified': data['isVerified'] ?? false,
            });
          }
        }
      }

      // Search in alpha_users collection
      final alphaUsersQuery = await _firestore
          .collection('alpha_users')
          .where('accountNumber', isEqualTo: query)
          .limit(5)
          .get();

      for (final doc in alphaUsersQuery.docs) {
        if (!seenIds.contains(doc.id)) {
          seenIds.add(doc.id);
          final data = doc.data();
          allResults.add({
            'id': doc.id,
            'name': data['name'] ?? 'Unknown User',
            'email': data['email'] ?? 'No email',
            'accountNumber': data['accountNumber'] ?? 'N/A',
            'phone': data['phone'] ?? '',
            'avatar': _getInitials(data['name'] ?? 'UU'),
            'avatarColor': _getAvatarColor(doc.id),
            'isFavorite': _userFavorites.contains(doc.id),
            'isOnline': data['isOnline'] ?? false,
            'lastActiveText': _getLastActiveText(data['lastActive']),
            'balance': data['balance'] ?? 0.0,
            'bank': data['bank'] ?? 'Alpha Bank',
            'role': 'alpha_user',
            'isVerified': true,
          });
        }
      }

      setState(() {
        _searchResults = allResults;
        _isLoadingSearch = false;
      });
    } catch (e) {
      print('Error searching users: $e');
      setState(() {
        _isLoadingSearch = false;
        _searchResults = [];
      });
    }
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.length >= 2
        ? name.substring(0, 2).toUpperCase()
        : name.padRight(2, ' ').toUpperCase();
  }

  String _getAvatarColor(String userId) {
    final colors = [
      '#1976D2',
      '#2E7D32',
      '#D32F2F',
      '#7B1FA2',
      '#FF9800',
      '#0097A7',
      '#388E3C',
      '#F57C00',
      '#5D4037',
      '#455A64',
    ];
    final index = userId.hashCode.abs() % colors.length;
    return colors[index];
  }

  void _startManualTransfer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => TransferInputSheet(
        onTransfer: (accountNumber, bank, name) {
          Navigator.pop(context);
          _startTransferToAccount(accountNumber, bank, name);
        },
      ),
    );
  }

  void _startTransferToAccount(String accountNumber, String bank, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => workflow.AmountInputScreen(
          recipientName: name,
          recipientAccount: accountNumber,
          transactionType: 'Bank Transfer',
          bankName: bank,
        ),
      ),
    );
  }

  void _startTransferToUser(Map<String, dynamic> user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => workflow.AmountInputScreen(
          recipientName: user['name'],
          recipientAccount: user['accountNumber'] ?? user['account'],
          transactionType:
              user['role'] == 'alpha_user' || user['type'] == 'alpha'
                  ? 'Alpha Users'
                  : 'Bank Transfer',
          bankName: user['bank'],
        ),
      ),
    );
  }

  Widget _buildSearchResultCard(Map<String, dynamic> user) {
    final isAlphaUser = user['role'] == 'alpha_user';
    final isVerified = user['isVerified'] ?? false;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        onTap: () => _startTransferToUser(user),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isAlphaUser
                  ? const Color(0xFF003366).withOpacity(0.2)
                  : Colors.grey.withOpacity(0.1),
            ),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Color(
                      int.parse(user['avatarColor'].substring(1), radix: 16) +
                          0xFF000000),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    user['avatar'],
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          user['name'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF003366),
                          ),
                        ),
                        if (isAlphaUser) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF003366).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Alpha',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF003366),
                              ),
                            ),
                          ),
                        ],
                        if (isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            color: Colors.green,
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user['accountNumber'] ?? user['account'] ?? 'N/A',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user['email'] ?? user['bank'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),

              // Action Button
              IconButton(
                onPressed: () => _startTransferToUser(user),
                icon: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF003366).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Color(0xFF003366),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentRecipientCard(Map<String, dynamic> recipient) {
    final lastTransfer = recipient['lastTransfer'] as Timestamp?;
    final lastTransferTime = lastTransfer?.toDate() ?? DateTime.now();
    final timeAgo = _getTimeAgo(lastTransferTime);
    final totalTransfers = recipient['totalTransfers'] ?? 0;
    final totalAmount = recipient['totalAmount'] ?? 0.0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        onTap: () => _startTransferToUser(recipient),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF003366).withOpacity(0.1),
            ),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Color(int.parse(recipient['avatarColor'].substring(1),
                          radix: 16) +
                      0xFF000000),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    recipient['avatar'],
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipient['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF003366),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recipient['account'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      recipient['bank'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$timeAgo • $totalTransfers transfers • \$${totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // Action Button
              IconButton(
                onPressed: () => _startTransferToUser(recipient),
                icon: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF003366).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Color(0xFF003366),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlphaUserCard(Map<String, dynamic> user) {
    final name = user['name'] as String;
    final initials = user['avatar'] as String;
    final account = user['accountNumber'] as String;
    final email = user['email'] as String;
    final balance = user['balanceFormatted'] as String;
    final isOnline = user['isOnline'] as bool;
    final lastActiveText = user['lastActiveText'] as String;
    final avatarColor = Color(
        int.parse(user['avatarColor'].toString().substring(1), radix: 16) +
            0xFF000000);
    final userId = user['id'] as String;
    final isFavorite = _userFavorites.contains(userId);
    final totalTransfers = user['totalTransfers'] ?? 0;
    final rating = user['rating'] ?? 0.0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      child: InkWell(
        onTap: () => _startTransferToUser(user),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.grey.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Avatar with Status
              Stack(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          avatarColor,
                          Color.lerp(avatarColor, Colors.black, 0.2)!,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: avatarColor.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (isFavorite)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: GestureDetector(
                        onTap: () => _toggleFavorite(userId, name, isFavorite),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.star_rounded,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.green : Colors.grey,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF003366),
                          ),
                        ),
                        Text(
                          balance,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF003366),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      account,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.email_rounded,
                          size: 12,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            email,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isOnline ? Colors.green : Colors.grey,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isOnline ? 'Online' : lastActiveText,
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                isOnline ? Colors.green[700] : Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        if (totalTransfers > 0)
                          Row(
                            children: [
                              const Icon(
                                Icons.swap_horiz_rounded,
                                size: 12,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$totalTransfers',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        if (rating > 0) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.star_rounded,
                            size: 12,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Send Button
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF003366),
                      Color(0xFF0055AA),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF003366).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: () => _startTransferToUser(user),
                  icon: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(
      String userId, String userName, bool isCurrentlyFavorite) async {
    if (_currentUserId == null) return;

    final favoritesRef = _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('alpha_user_favorites')
        .doc(userId);

    try {
      if (isCurrentlyFavorite) {
        await favoritesRef.delete();
        setState(() {
          _userFavorites.remove(userId);
        });
      } else {
        await favoritesRef.set({
          'userId': userId,
          'userName': userName,
          'addedAt': FieldValue.serverTimestamp(),
        });
        setState(() {
          _userFavorites.add(userId);
        });
      }
    } catch (e) {
      print('Error toggling favorite: $e');
    }
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.white,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFD),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF003366),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          color: const Color(0xFF003366),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              // App Bar with Search
              SliverAppBar(
                backgroundColor: const Color(0xFF003366),
                expandedHeight: 120,
                floating: true,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                  title: _isSearching
                      ? Text(
                          'Search Results',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        )
                      : Text(
                          'Alpha Network',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF003366),
                          Color(0xFF0055AA),
                        ],
                      ),
                    ),
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(80),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    color: const Color(0xFF003366),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              decoration: InputDecoration(
                                hintText:
                                    'Search by name, email, or account number...',
                                hintStyle: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  color: Colors.grey[500],
                                ),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(
                                          Icons.close_rounded,
                                          color: Colors.grey[500],
                                        ),
                                        onPressed: () {
                                          _searchController.clear();
                                          _searchFocusNode.unfocus();
                                        },
                                      )
                                    : null,
                              ),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF003366),
                                fontWeight: FontWeight.w500,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.deny(RegExp(r'\n')),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF003366),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              onPressed: _startManualTransfer,
                              icon: const Icon(
                                Icons.qr_code_scanner_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Search Results or Main Content
              if (_isSearching)
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (_isLoadingSearch)
                        const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF003366),
                          ),
                        )
                      else if (_searchResults.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 60,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No users found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try searching by name, email, or account number',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              OutlinedButton(
                                onPressed: _startManualTransfer,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF003366),
                                  side: const BorderSide(
                                      color: Color(0xFF003366)),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Enter Account Manually'),
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_searchResults.length} results found',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 16),
                            ..._searchResults.map((user) => Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: _buildSearchResultCard(user),
                                )),
                            const SizedBox(height: 20),
                            Center(
                              child: OutlinedButton(
                                onPressed: _startManualTransfer,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF003366),
                                  side: const BorderSide(
                                      color: Color(0xFF003366)),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                    'Not found? Enter account manually'),
                              ),
                            ),
                          ],
                        ),
                    ]),
                  ),
                )
              else
                // Main Content
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Statistics Card
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF003366),
                              Color(0xFF0055AA),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF003366).withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Alpha Network',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Instant transfers to Alpha customers',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      _buildStatItem(
                                        'Recent',
                                        _recentRecipients.length.toString(),
                                        Icons.history_rounded,
                                      ),
                                      const SizedBox(width: 12),
                                      _buildStatItem(
                                        'Transfers',
                                        _recentTransfers.length.toString(),
                                        Icons.swap_horiz_rounded,
                                      ),
                                      const SizedBox(width: 12),
                                      _buildStatItem(
                                        'Alpha',
                                        _alphaBankUsers.length.toString(),
                                        Icons.people_alt_rounded,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.bolt_rounded,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Recent Recipients Section
                      if (_recentRecipients.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Recent Recipients',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF003366),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  Text(
                                    '${_recentRecipients.length} contacts',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'People you\'ve sent money to recently',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: _recentRecipients
                              .take(5)
                              .map((recipient) => Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: _buildRecentRecipientCard(recipient),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Recent Transfers Section
                      if (_recentTransfers.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Recent Transfers',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF003366),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  Text(
                                    '${_recentTransfers.length} transfers',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Your recent money transfers',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: _recentTransfers
                              .take(5)
                              .map((transfer) => Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: _buildSearchResultCard(transfer),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Alpha Bank Users Section
                      if (_alphaBankUsers.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Alpha Bank Users',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF003366),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  Text(
                                    '${_alphaBankUsers.length} users',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Active Alpha Bank customers',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: _alphaBankUsers
                              .where((user) =>
                                  user['isOnline'] == true || _showOnlineOnly
                                      ? user['isOnline'] == true
                                      : true)
                              .where((user) => _showFavoritesOnly
                                  ? _userFavorites.contains(user['id'])
                                  : true)
                              .take(10)
                              .map((user) => Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    child: _buildAlphaUserCard(user),
                                  ))
                              .toList(),
                        ),
                      ],

                      // No Data State
                      if (_recentRecipients.isEmpty &&
                          _recentTransfers.isEmpty &&
                          _alphaBankUsers.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            children: [
                              Icon(
                                Icons.people_outline_rounded,
                                size: 60,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No transaction history',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Start sending money to see your recent recipients here',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: _startManualTransfer,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF003366),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Send Money Now'),
                              ),
                            ],
                          ),
                        ),
                    ]),
                  ),
                ),

              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          ),
        ),
      ),
      floatingActionButton: !_isSearching
          ? Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: FloatingActionButton.extended(
                onPressed: _startManualTransfer,
                backgroundColor: const Color(0xFF003366),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 8,
                icon: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Color(0xFF003366),
                    size: 16,
                  ),
                ),
                label: const Text(
                  'Send Money',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _transactionsListener?.cancel();
    super.dispose();
  }
}

// Manual Transfer Input Sheet
class TransferInputSheet extends StatefulWidget {
  final Function(String accountNumber, String bank, String name) onTransfer;

  const TransferInputSheet({
    super.key,
    required this.onTransfer,
  });

  @override
  State<TransferInputSheet> createState() => _TransferInputSheetState();
}

class _TransferInputSheetState extends State<TransferInputSheet> {
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _bankController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  bool _accountFound = false;

  @override
  void initState() {
    super.initState();
    _accountController.addListener(_searchAccount);
  }

  Future<void> _searchAccount() async {
    final accountNumber = _accountController.text.trim();

    if (accountNumber.length < 3) {
      setState(() {
        _accountFound = false;
        _bankController.clear();
        _nameController.clear();
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Search in users collection
      final usersQuery = await _firestore
          .collection('users')
          .where('accountNumber', isEqualTo: accountNumber)
          .limit(1)
          .get();

      if (usersQuery.docs.isNotEmpty) {
        final user = usersQuery.docs.first.data();
        setState(() {
          _accountFound = true;
          _nameController.text = user['name'] ?? '';
          _bankController.text = user['bankName'] ?? 'Alpha Bank';
        });
        return;
      }

      // Search in alpha_users collection
      final alphaUsersQuery = await _firestore
          .collection('alpha_users')
          .where('accountNumber', isEqualTo: accountNumber)
          .limit(1)
          .get();

      if (alphaUsersQuery.docs.isNotEmpty) {
        final user = alphaUsersQuery.docs.first.data();
        setState(() {
          _accountFound = true;
          _nameController.text = user['name'] ?? '';
          _bankController.text = user['bank'] ?? 'Alpha Bank';
        });
        return;
      }

      setState(() {
        _accountFound = false;
        _nameController.text = '';
        _bankController.text = '';
      });
    } catch (e) {
      print('Error searching account: $e');
      setState(() {
        _accountFound = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Transfer Money',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF003366),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Enter recipient details to send money',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _accountController,
            decoration: InputDecoration(
              labelText: 'Account Number',
              prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
              suffixIcon: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _accountFound
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green,
                        )
                      : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Recipient Name',
              prefixIcon: const Icon(Icons.person_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            readOnly: _accountFound,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _bankController,
            decoration: InputDecoration(
              labelText: 'Bank',
              prefixIcon: const Icon(Icons.account_balance_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            readOnly: _accountFound,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF003366),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _accountController.text.isNotEmpty &&
                          _nameController.text.isNotEmpty
                      ? () {
                          widget.onTransfer(
                            _accountController.text.trim(),
                            _bankController.text.trim(),
                            _nameController.text.trim(),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003366),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
