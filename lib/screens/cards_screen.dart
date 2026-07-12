import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CardsScreen extends StatefulWidget {
  const CardsScreen({super.key});

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  int _selectedCardIndex = 0;
  List<BankCard> _cards = [];
  bool _isLoading = true;
  User? _currentUser;
  DocumentReference? _userRef;
  double _userBalance = 0.0;
  String? _primaryAccountNumber;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
  }

  void _initializeFirebase() async {
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      _userRef =
          FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid);
      await _loadUserData();
      await _loadCards();
    }
  }

  Future<void> _loadUserData() async {
    try {
      if (_userRef == null) return;

      final userDoc = await _userRef!.get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _userBalance = (userData['balance'] ?? 0.0).toDouble();
          _primaryAccountNumber = userData['accountNumber'] ?? 'ALPHA001';
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadCards() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_userRef == null) return;

      final cardsSnapshot = await _userRef!.collection('cards').get();

      final cards = cardsSnapshot.docs.map((doc) {
        final data = doc.data();
        return BankCard.fromFirestore(doc.id, data);
      }).toList();

      // Sort cards: primary first, then by status
      cards.sort((a, b) {
        if (a.isPrimary) return -1;
        if (b.isPrimary) return 1;
        return a.status.index.compareTo(b.status.index);
      });

      setState(() {
        _cards = cards;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading cards: $e');
      setState(() {
        _isLoading = false;
      });

      // Fallback to sample data if Firebase fails
      _loadSampleCards();
    }
  }

  void _loadSampleCards() {
    setState(() {
      _cards = [
        BankCard(
          id: '1',
          cardNumber: '**** **** **** 1234',
          maskedCardNumber: '**** **** **** 1234',
          cardHolder: 'JOHN DOE',
          expiryDate: '08/25',
          expiryMonth: '08',
          expiryYear: '2025',
          cvv: '123',
          maskedCvv: '***',
          type: CardType.visa,
          color: const Color(0xFF003366),
          isVirtual: true,
          balance: 50000.00,
          dailyLimit: 100000.00,
          monthlyLimit: 500000.00,
          transactionLimit: 50000.00,
          spentToday: 45250.00,
          spentThisMonth: 152840.00,
          status: CardStatus.active,
          isPrimary: true,
          currency: 'NGN',
          bankName: 'Alpha Bank',
          cardType: 'debit',
        ),
        BankCard(
          id: '2',
          cardNumber: '**** **** **** 5678',
          maskedCardNumber: '**** **** **** 5678',
          cardHolder: 'JOHN DOE',
          expiryDate: '12/26',
          expiryMonth: '12',
          expiryYear: '2026',
          cvv: '456',
          maskedCvv: '***',
          type: CardType.mastercard,
          color: Colors.blue[900]!,
          isVirtual: false,
          balance: 75000.00,
          dailyLimit: 150000.00,
          monthlyLimit: 1000000.00,
          transactionLimit: 75000.00,
          spentToday: 0.00,
          spentThisMonth: 245600.00,
          status: CardStatus.active,
          isPrimary: false,
          currency: 'NGN',
          bankName: 'Alpha Bank',
          cardType: 'credit',
        ),
        BankCard(
          id: '3',
          cardNumber: '**** **** **** 9012',
          maskedCardNumber: '**** **** **** 9012',
          cardHolder: 'JOHN DOE',
          expiryDate: '03/25',
          expiryMonth: '03',
          expiryYear: '2025',
          cvv: '789',
          maskedCvv: '***',
          type: CardType.visa,
          color: Colors.blueGrey[900]!,
          isVirtual: true,
          balance: 25000.00,
          dailyLimit: 50000.00,
          monthlyLimit: 250000.00,
          transactionLimit: 25000.00,
          spentToday: 12500.00,
          spentThisMonth: 87500.00,
          status: CardStatus.frozen,
          isPrimary: false,
          currency: 'USD',
          bankName: 'Alpha Bank International',
          cardType: 'debit',
        ),
      ];
      _isLoading = false;
    });
  }

  Future<void> _createCardTransaction(
      Map<String, dynamic> cardTransactionData, BankCard card) async {
    try {
      if (_userRef == null) return;

      // Get the current card to update balances
      final cardDoc = await _userRef!.collection('cards').doc(card.id).get();
      if (!cardDoc.exists) return;

      final cardData = cardDoc.data() as Map<String, dynamic>;
      final currentCardBalance = (cardData['balance'] ?? 0.0).toDouble();
      final currentSpentToday = (cardData['spentToday'] ?? 0.0).toDouble();
      final currentSpentThisMonth =
          (cardData['spentThisMonth'] ?? 0.0).toDouble();
      final transactionAmount =
          (cardTransactionData['amount'] as num).toDouble();

      // Update card balances
      final updates = <String, dynamic>{
        'balance': currentCardBalance - transactionAmount,
        'updatedAt': Timestamp.now(),
      };

      // Update spent today and this month for negative amounts (purchases)
      if (transactionAmount < 0) {
        updates['spentToday'] = currentSpentToday + transactionAmount.abs();
        updates['spentThisMonth'] =
            currentSpentThisMonth + transactionAmount.abs();
      }

      // Update user balance for card transactions that affect main balance
      if (card.cardType == 'debit') {
        await _userRef!.update({
          'balance': FieldValue.increment(-transactionAmount),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update card document
      await _userRef!.collection('cards').doc(card.id).update(updates);

      // Create main transaction record
      final transactionId = cardTransactionData['id'] as String;
      final mainTransactionRef =
          _userRef!.collection('transactions').doc(transactionId);

      final userName = _currentUser?.displayName ??
          (_currentUser?.email?.split('@').first ?? 'User');

      final mainTransactionData = {
        'amount': transactionAmount,
        'description': cardTransactionData['description'] as String,
        'type': cardTransactionData['type'] as String,
        'timestamp': cardTransactionData['timestamp'] as Timestamp,
        'status': cardTransactionData['status'] as String,
        'from': userName,
        'to': cardTransactionData['merchant'] as String? ?? 'Merchant',
        'balanceAfter':
            _userBalance - (card.cardType == 'debit' ? transactionAmount : 0),
        'category': cardTransactionData['category'] as String? ?? 'card',
        'accountNumber': _primaryAccountNumber,
        'transactionId': transactionId,
        'createdAt': FieldValue.serverTimestamp(),
        'securityLevel': 'medium',
        'requiresVerification': false,
        'verified': true,
        'transactionType': 'card_transaction',
        'cardTransactionDetails': {
          'cardId': card.id,
          'cardNumber': card.maskedCardNumber,
          'cardType': card.cardType,
          'bankName': card.bankName,
          'merchant': cardTransactionData['merchant'] as String?,
          'merchantCategory':
              cardTransactionData['merchantCategory'] as String?,
          'location': cardTransactionData['location'] as String?,
          'country': cardTransactionData['country'] as String?,
          'isInternational':
              cardTransactionData['isInternational'] as bool? ?? false,
          'authCode': cardTransactionData['authCode'] as String?,
          'referenceNumber': cardTransactionData['referenceNumber'] as String?,
          'cardBalanceAfter': currentCardBalance - transactionAmount,
          'currency': card.currency,
        },
      };

      await mainTransactionRef.set(mainTransactionData);

      // Also store in card transactions subcollection (existing structure)
      final cardTransactionRef = _userRef!
          .collection('cards')
          .doc(card.id)
          .collection('transactions')
          .doc(transactionId);

      await cardTransactionRef.set(cardTransactionData);
    } catch (e) {
      print('Error creating card transaction: $e');
      rethrow;
    }
  }

  Future<void> _makeTestCardTransaction() async {
    if (_cards.isEmpty || _selectedCardIndex >= _cards.length) return;

    final currentCard = _cards[_selectedCardIndex];

    // Create a sample card transaction
    final transactionId = 'CARD${DateTime.now().millisecondsSinceEpoch}';
    final transactionData = {
      'id': transactionId,
      'amount': -5000.00,
      'description': 'Test Online Purchase',
      'merchant': 'Test Store',
      'merchantCategory': 'E-commerce',
      'type': 'purchase',
      'timestamp': Timestamp.now(),
      'status': 'completed',
      'currency': currentCard.currency,
      'location': 'Online',
      'country': 'US',
      'isInternational': true,
      'authCode': 'AUTH${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
      'referenceNumber': 'REF${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
      'balanceAfter': currentCard.balance - 5000.00,
      'category': 'shopping',
      'tags': ['test', 'online'],
      'notes': 'Test transaction',
      'receiptUrl': null,
      'createdAt': Timestamp.now(),
    };

    try {
      await _createCardTransaction(transactionData, currentCard);

      // Update local state
      setState(() {
        currentCard.balance -= 5000.00;
        currentCard.spentToday += 5000.00;
        currentCard.spentThisMonth += 5000.00;
        if (currentCard.cardType == 'debit') {
          _userBalance -= 5000.00;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Test transaction created successfully'),
          backgroundColor: Colors.green[700],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to create test transaction'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleCardFreeze(BankCard card) async {
    try {
      final newStatus = card.status == CardStatus.active
          ? CardStatus.frozen
          : CardStatus.active;

      if (_userRef != null) {
        await _userRef!.collection('cards').doc(card.id).update({
          'status': newStatus.toString().split('.').last,
          'updatedAt': Timestamp.now(),
          if (newStatus == CardStatus.frozen) 'frozenAt': Timestamp.now(),
        });
      }

      setState(() {
        card.status = newStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == CardStatus.frozen
                ? 'Card has been frozen'
                : 'Card has been activated',
          ),
          backgroundColor: newStatus == CardStatus.frozen
              ? Colors.orange[700]
              : Colors.green[700],
        ),
      );
    } catch (e) {
      print('Error updating card status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update card status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _changeCardPin() async {
    final currentCard = _cards[_selectedCardIndex];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Card PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your new 4-digit PIN'),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextFormField(
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                  hintText: 'Enter 4-digit PIN',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Update PIN in Firebase
              if (_userRef != null) {
                await _userRef!.collection('cards').doc(currentCard.id).update({
                  'pinSet': true,
                  'updatedAt': Timestamp.now(),
                });
              }

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('PIN changed successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Change PIN'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadCardDetails() async {
    final currentCard = _cards[_selectedCardIndex];

    // In a real app, you might generate a PDF or save to device
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Downloading details for card ${currentCard.maskedCardNumber}'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _reportCardIssue() async {
    final currentCard = _cards[_selectedCardIndex];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Card Issue'),
        content: const Text(
            'Are you sure you want to report this card as lost or stolen? This will immediately block the card.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Update card status in Firebase
              if (_userRef != null) {
                await _userRef!.collection('cards').doc(currentCard.id).update({
                  'status': 'blocked',
                  'updatedAt': Timestamp.now(),
                  'blockedAt': Timestamp.now(),
                  'blockReason': 'lost_stolen',
                });
              }

              Navigator.pop(context);
              setState(() {
                currentCard.status = CardStatus.blocked;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Card has been reported and blocked'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  Future<void> _viewAllCardTransactions() async {
    final currentCard = _cards[_selectedCardIndex];

    // Navigate to card transactions screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CardTransactionsScreen(cardId: currentCard.id),
      ),
    );
  }

  Future<void> _orderNewCard() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Order New Card',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Choose the type of card you want to order',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            _buildCardOption(
              'Virtual Card',
              'Instant digital card',
              Icons.credit_card_rounded,
              Colors.blue,
              () => _processCardOrder(true),
            ),
            const SizedBox(height: 12),
            _buildCardOption(
              'Physical Card',
              'Delivered to your address',
              Icons.card_membership_rounded,
              Colors.green,
              () => _processCardOrder(false),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _processCardOrder(bool isVirtual) async {
    Navigator.pop(context);

    // Generate new card data
    final newCardId = 'card_${DateTime.now().millisecondsSinceEpoch}';
    final userName = _currentUser?.displayName?.toUpperCase() ?? 'USER';
    final lastFour =
        DateTime.now().millisecondsSinceEpoch.toString().substring(9, 13);

    final newCard = {
      'id': newCardId,
      'cardNumber': '${isVirtual ? '4' : '5'}23456789012$lastFour',
      'maskedCardNumber': '**** **** **** $lastFour',
      'cardHolder': userName,
      'expiryDate':
          '${DateTime.now().add(const Duration(days: 365 * 3)).month.toString().padLeft(2, '0')}/${DateTime.now().add(const Duration(days: 365 * 3)).year.toString().substring(2)}',
      'expiryMonth': DateTime.now()
          .add(const Duration(days: 365 * 3))
          .month
          .toString()
          .padLeft(2, '0'),
      'expiryYear':
          DateTime.now().add(const Duration(days: 365 * 3)).year.toString(),
      'cvv': '${DateTime.now().millisecondsSinceEpoch % 1000}'.padLeft(3, '0'),
      'maskedCvv': '***',
      'type': isVirtual ? 'visa' : 'mastercard',
      'color': isVirtual ? '#003366' : '#0d47a1',
      'isVirtual': isVirtual,
      'balance': 0.00,
      'dailyLimit': 100000.00,
      'monthlyLimit': 500000.00,
      'transactionLimit': 50000.00,
      'spentToday': 0.00,
      'spentThisMonth': 0.00,
      'status': 'pending',
      'isPrimary': false,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'currency': 'NGN',
      'bankName': 'Alpha Bank',
      'cardType': 'debit',
      'issuer': 'Alpha Bank Nigeria',
    };

    try {
      if (_userRef != null) {
        // Create card in Firebase
        await _userRef!.collection('cards').doc(newCardId).set(newCard);

        // Create a transaction record for the card order
        final transactionId =
            'CARD_ORDER${DateTime.now().millisecondsSinceEpoch}';
        final transactionData = {
          'amount': 0.00,
          'description': '${isVirtual ? 'Virtual' : 'Physical'} Card Order',
          'type': 'card_order',
          'timestamp': Timestamp.now(),
          'status': 'completed',
          'from': 'Alpha Bank',
          'to': userName,
          'balanceAfter': _userBalance,
          'category': 'banking',
          'accountNumber': _primaryAccountNumber,
          'transactionId': transactionId,
          'createdAt': FieldValue.serverTimestamp(),
          'securityLevel': 'low',
          'requiresVerification': false,
          'verified': true,
          'transactionType': 'card_order',
          'cardOrderDetails': {
            'cardId': newCardId,
            'cardNumber': newCard['maskedCardNumber'],
            'cardType': isVirtual ? 'Virtual' : 'Physical',
            'network': isVirtual ? 'Visa' : 'Mastercard',
            'bankName': 'Alpha Bank',
            'orderType': 'new_card',
          },
        };

        await _userRef!
            .collection('transactions')
            .doc(transactionId)
            .set(transactionData);

        await _loadCards(); // Reload cards

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${isVirtual ? 'Virtual' : 'Physical'} card ordered successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error ordering card: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to order card'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildCardOption(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey[200]!,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF003366),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF003366).withOpacity(0.05),
                    const Color(0xFF004080).withOpacity(0.03),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Header
                    SizedBox(
                      height: 60,
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                                  size: 20),
                              color: const Color(0xFF003366),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'My Cards',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF003366),
                            ),
                          ),
                          const Spacer(),
                          if (_cards.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.shopping_cart_rounded,
                                  color: Color(0xFF003366)),
                              onPressed: _makeTestCardTransaction,
                              tooltip: 'Test Card Transaction',
                            ),
                          IconButton(
                            icon: const Icon(Icons.add_card_rounded,
                                color: Color(0xFF003366)),
                            onPressed: _orderNewCard,
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded,
                                color: Color(0xFF003366)),
                            onPressed: _loadCards,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_cards.isEmpty)
                      _buildNoCardsView()
                    else ...[
                      // Cards Carousel
                      SizedBox(
                        height: 220,
                        child: PageView.builder(
                          controller: PageController(viewportFraction: 0.85),
                          itemCount: _cards.length,
                          onPageChanged: (index) {
                            setState(() {
                              _selectedCardIndex = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            final card = _cards[index];
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: _buildCard(card, index),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Card Indicator Dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _cards.length,
                          (index) => Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _selectedCardIndex == index
                                  ? const Color(0xFF003366)
                                  : Colors.grey[300],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Current Card Details
                      _buildCardDetails(_cards[_selectedCardIndex]),
                      const SizedBox(height: 20),

                      // Quick Actions
                      const Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF003366),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        children: [
                          _buildCardAction(
                            icon: Icons.lock_rounded,
                            title: _cards[_selectedCardIndex].status ==
                                    CardStatus.active
                                ? 'Freeze Card'
                                : 'Unfreeze Card',
                            subtitle: _cards[_selectedCardIndex].status ==
                                    CardStatus.active
                                ? 'Temporarily block card'
                                : 'Activate card',
                            color: _cards[_selectedCardIndex].status ==
                                    CardStatus.active
                                ? Colors.orange[700]!
                                : Colors.green[700]!,
                            onTap: () =>
                                _toggleCardFreeze(_cards[_selectedCardIndex]),
                          ),
                          _buildCardAction(
                            icon: Icons.change_circle_rounded,
                            title: 'Change PIN',
                            subtitle: 'Update card PIN',
                            color: Colors.blue[700]!,
                            onTap: _changeCardPin,
                          ),
                          _buildCardAction(
                            icon: Icons.download_rounded,
                            title: 'Download',
                            subtitle: 'Save card details',
                            color: Colors.green[700]!,
                            onTap: _downloadCardDetails,
                          ),
                          _buildCardAction(
                            icon: Icons.report_rounded,
                            title: 'Report Issue',
                            subtitle: 'Lost or stolen card',
                            color: Colors.red[700]!,
                            onTap: _reportCardIssue,
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // Card Limits
                      _buildCardLimits(_cards[_selectedCardIndex]),

                      const SizedBox(height: 30),

                      // Recent Card Transactions
                      CardTransactionsPreview(
                          cardId: _cards[_selectedCardIndex].id),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoCardsView() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.credit_card_off_rounded,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 20),
          const Text(
            'No Cards Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF003366),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Get started by ordering your first card',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _orderNewCard,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003366),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Order Your First Card',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BankCard card, int index) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            card.color,
            card.color.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: card.color.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Card Background Pattern
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 20,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),

          // Card Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      card.bankName,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    if (card.isVirtual)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Virtual',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  card.maskedCardNumber,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Card Holder',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        Text(
                          card.cardHolder,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expires',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        Text(
                          card.expiryDate,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 50,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Center(
                        child: Text(
                          card.type == CardType.visa ? 'VISA' : 'MC',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (card.status == CardStatus.frozen ||
                    card.status == CardStatus.blocked)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: (card.status == CardStatus.frozen
                              ? Colors.orange
                              : Colors.red)
                          .withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (card.status == CardStatus.frozen
                                ? Colors.orange
                                : Colors.red)
                            .withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_rounded,
                            color: (card.status == CardStatus.frozen
                                ? Colors.orange
                                : Colors.red)[200],
                            size: 12),
                        const SizedBox(width: 4),
                        Text(
                          card.status == CardStatus.frozen
                              ? 'Card Frozen'
                              : 'Card Blocked',
                          style: TextStyle(
                            fontSize: 10,
                            color: (card.status == CardStatus.frozen
                                ? Colors.orange
                                : Colors.red)[200],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardDetails(BankCard card) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 15,
            spreadRadius: 3,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Card Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF003366),
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow('Card Balance',
              '${card.currency} ${card.balance.toStringAsFixed(2)}'),
          _buildDetailRow('Daily Limit',
              '${card.currency} ${card.dailyLimit.toStringAsFixed(2)}'),
          _buildDetailRow(
              'Card Status',
              card.status == CardStatus.active
                  ? 'Active'
                  : card.status == CardStatus.frozen
                      ? 'Frozen'
                      : 'Blocked'),
          _buildDetailRow('Card Type', card.isVirtual ? 'Virtual' : 'Physical'),
          _buildDetailRow('Card Network',
              card.type == CardType.visa ? 'Visa' : 'Mastercard'),
          _buildDetailRow('Currency', card.currency),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF003366),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF003366),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardLimits(BankCard card) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 15,
            spreadRadius: 3,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Card Limits',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF003366),
            ),
          ),
          const SizedBox(height: 16),
          _buildLimitRow(
              'Daily Limit',
              '${card.currency} ${card.dailyLimit.toStringAsFixed(2)}',
              '${card.currency} ${card.spentToday.toStringAsFixed(2)} spent'),
          const SizedBox(height: 12),
          _buildLimitRow(
              'Transaction Limit',
              '${card.currency} ${card.transactionLimit.toStringAsFixed(2)}',
              'Per transaction'),
          const SizedBox(height: 12),
          _buildLimitRow(
              'Monthly Limit',
              '${card.currency} ${card.monthlyLimit.toStringAsFixed(2)}',
              '${card.currency} ${card.spentThisMonth.toStringAsFixed(2)} spent'),
        ],
      ),
    );
  }

  Widget _buildLimitRow(String title, String limit, String status) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            Text(
              limit,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF003366),
              ),
            ),
          ],
        ),
        Text(
          status,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }
}

// Card Transactions Preview Widget
class CardTransactionsPreview extends StatelessWidget {
  final String cardId;

  const CardTransactionsPreview({super.key, required this.cardId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .collection('cards')
          .doc(cardId)
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 15,
                  spreadRadius: 3,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Center(child: Text('Error loading transactions')),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 15,
                  spreadRadius: 3,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final transactions = snapshot.data?.docs ?? [];

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 15,
                spreadRadius: 3,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Card Transactions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF003366),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              CardTransactionsScreen(cardId: cardId),
                        ),
                      );
                    },
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0055AA),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (transactions.isEmpty)
                const Center(child: Text('No card transactions yet'))
              else
                ...transactions.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildTransactionItem(data);
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final amount = transaction['amount'] as num;
    final description = transaction['description'] as String;
    final timestamp = transaction['timestamp'] as Timestamp;
    final date = _formatDate(timestamp.toDate());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getTransactionIcon(transaction['category']),
              color: Colors.grey[600],
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${amount >= 0 ? '+' : ''}${transaction['currency'] ?? ''} ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: amount >= 0 ? Colors.green[700] : Colors.red[700],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  IconData _getTransactionIcon(String category) {
    switch (category) {
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'entertainment':
        return Icons.movie_rounded;
      case 'groceries':
        return Icons.shopping_cart_rounded;
      case 'cash':
        return Icons.atm_rounded;
      case 'income':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.receipt_rounded;
    }
  }
}

// Card Transactions Screen
class CardTransactionsScreen extends StatelessWidget {
  final String cardId;

  const CardTransactionsScreen({super.key, required this.cardId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Card Transactions'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .collection('cards')
            .doc(cardId)
            .collection('transactions')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading transactions'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final transactions = snapshot.data?.docs ?? [];

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final doc = transactions[index];
              final data = doc.data() as Map<String, dynamic>;

              return CardTransactionItem(transaction: data);
            },
          );
        },
      ),
    );
  }
}

// Card Transaction Item Widget
class CardTransactionItem extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const CardTransactionItem({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final amount = transaction['amount'] as num;
    final description = transaction['description'] as String;
    final merchant = transaction['merchant'] as String?;
    final timestamp = transaction['timestamp'] as Timestamp;
    final date = timestamp.toDate();
    final category = transaction['category'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getCategoryColor(category).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getCategoryIcon(category),
              color: _getCategoryColor(category),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (merchant != null)
                  Text(
                    merchant,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                Text(
                  '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${amount >= 0 ? '+' : ''}${transaction['currency'] ?? ''} ${amount.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: amount >= 0 ? Colors.green[700] : Colors.red[700],
                ),
              ),
              if (transaction['balanceAfter'] != null)
                Text(
                  'Balance: ${transaction['currency'] ?? ''} ${(transaction['balanceAfter'] as num).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'shopping':
        return Colors.blue;
      case 'entertainment':
        return Colors.purple;
      case 'groceries':
        return Colors.green;
      case 'cash':
        return Colors.orange;
      case 'income':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String? category) {
    switch (category) {
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'entertainment':
        return Icons.movie_rounded;
      case 'groceries':
        return Icons.shopping_cart_rounded;
      case 'cash':
        return Icons.atm_rounded;
      case 'income':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.receipt_rounded;
    }
  }
}

enum CardType { visa, mastercard }

enum CardStatus { active, frozen, blocked }

class BankCard {
  final String id;
  final String cardNumber;
  final String maskedCardNumber;
  final String cardHolder;
  final String expiryDate;
  final String expiryMonth;
  final String expiryYear;
  final String cvv;
  final String maskedCvv;
  final CardType type;
  final Color color;
  final bool isVirtual;
  double balance;
  final double dailyLimit;
  final double monthlyLimit;
  final double transactionLimit;
  double spentToday;
  double spentThisMonth;
  CardStatus status;
  final bool isPrimary;
  final String currency;
  final String bankName;
  final String cardType;

  BankCard({
    required this.id,
    required this.cardNumber,
    required this.maskedCardNumber,
    required this.cardHolder,
    required this.expiryDate,
    required this.expiryMonth,
    required this.expiryYear,
    required this.cvv,
    required this.maskedCvv,
    required this.type,
    required this.color,
    required this.isVirtual,
    required this.balance,
    required this.dailyLimit,
    required this.monthlyLimit,
    required this.transactionLimit,
    required this.spentToday,
    required this.spentThisMonth,
    required this.status,
    required this.isPrimary,
    required this.currency,
    required this.bankName,
    required this.cardType,
  });

  factory BankCard.fromFirestore(String id, Map<String, dynamic> data) {
    return BankCard(
      id: id,
      cardNumber: data['cardNumber'] ?? '',
      maskedCardNumber: data['maskedCardNumber'] ?? '**** **** **** ****',
      cardHolder: data['cardHolder'] ?? 'CARDHOLDER',
      expiryDate: data['expiryDate'] ?? 'MM/YY',
      expiryMonth: data['expiryMonth'] ?? '01',
      expiryYear: data['expiryYear'] ?? '2025',
      cvv: data['cvv'] ?? '000',
      maskedCvv: data['maskedCvv'] ?? '***',
      type: (data['type'] ?? 'visa') == 'visa'
          ? CardType.visa
          : CardType.mastercard,
      color: _parseColor(data['color'] ?? '#003366'),
      isVirtual: data['isVirtual'] ?? false,
      balance: (data['balance'] ?? 0.0).toDouble(),
      dailyLimit: (data['dailyLimit'] ?? 100000.0).toDouble(),
      monthlyLimit: (data['monthlyLimit'] ?? 500000.0).toDouble(),
      transactionLimit: (data['transactionLimit'] ?? 50000.0).toDouble(),
      spentToday: (data['spentToday'] ?? 0.0).toDouble(),
      spentThisMonth: (data['spentThisMonth'] ?? 0.0).toDouble(),
      status: _parseStatus(data['status'] ?? 'active'),
      isPrimary: data['isPrimary'] ?? false,
      currency: data['currency'] ?? 'NGN',
      bankName: data['bankName'] ?? 'Alpha Bank',
      cardType: data['cardType'] ?? 'debit',
    );
  }

  static Color _parseColor(String colorString) {
    try {
      if (colorString.startsWith('#')) {
        return Color(
            int.parse(colorString.substring(1), radix: 16) + 0xFF000000);
      }
    } catch (e) {
      print('Error parsing color: $e');
    }
    return const Color(0xFF003366);
  }

  static CardStatus _parseStatus(String statusString) {
    switch (statusString) {
      case 'active':
        return CardStatus.active;
      case 'frozen':
        return CardStatus.frozen;
      case 'blocked':
        return CardStatus.blocked;
      default:
        return CardStatus.active;
    }
  }
}
