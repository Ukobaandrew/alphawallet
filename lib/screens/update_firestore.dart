import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import '../firebase_options.dart';

// Set your actual admin UID here
const String ADMIN_UID =
    'WpieYuOivOgdYsIWKoheJ86y94E3'; // Replace with actual UID
const String ADMIN_EMAIL = 'admin@gmail.com';

void main() async {
  print('🚀 Starting Firestore database update...\n');

  try {
    // Initialize Firebase
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await setupAdminUser();
    await updateAllUsers();
    await updateExchangeRates();
    await setupExchangeHistory();
    await setupCardsCollection();
    await setupLiveChatSystem();
    await setupTransferSystem();
    await setupBanksAndCountries();
    await setupDepositSystem(); // Add this line
    print('\n🎉 Database update completed successfully!');
  } catch (e) {
    print('\n❌ Error during update: $e');
  }
}

// ============= TRANSFER SYSTEM SETUP =============
Future<void> setupTransferSystem() async {
  try {
    final firestore = FirebaseFirestore.instance;

    print('🔄 Setting up transfer system...');

    // Create transfer settings
    await createTransferSettings(firestore);

    // Create sample transfer templates
    await createTransferTemplates(firestore);

    // Create transfer fees structure
    await createTransferFees(firestore);

    print('   ✅ Transfer system setup completed\n');
  } catch (e) {
    print('   ❌ Error setting up transfer system: $e');
  }
}

Future<void> createTransferSettings(FirebaseFirestore firestore) async {
  try {
    final settingsRef = firestore.collection('transfer_settings').doc('global');
    final existingSettings = await settingsRef.get();

    if (!existingSettings.exists) {
      print('   ⚙️ Creating transfer settings...');

      await settingsRef.set({
        'maxTransferAmount': 50000.00,
        'minTransferAmount': 10.00,
        'dailyTransferLimit': 100000.00,
        'monthlyTransferLimit': 500000.00,
        'instantTransferFee': 1.5, // percentage
        'standardTransferFee': 0.5, // percentage
        'instantTransferMax': 10000.00,
        'requiresVerificationAbove': 5000.00,
        'autoApproveBelow': 1000.00,
        'processingTimes': {
          'instant': '5-30 minutes',
          'standard': '1-2 business days',
          'international': '2-5 business days',
        },
        'supportedCurrencies': ['USD', 'EUR', 'GBP', 'NGN', 'CAD', 'AUD'],
        'exchangeMargin': 0.5, // percentage
        'lastUpdated': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('   ✅ Created transfer settings');
    } else {
      print('   ℹ️ Transfer settings already exist');
    }
  } catch (e) {
    print('   ❌ Error creating transfer settings: $e');
  }
}

Future<void> createTransferTemplates(FirebaseFirestore firestore) async {
  try {
    final templatesRef = firestore.collection('transfer_templates');
    final existingTemplates = await templatesRef.limit(1).get();

    if (existingTemplates.docs.isEmpty) {
      print('   📋 Creating transfer templates...');

      final templates = [
        {
          'id': 'template_1',
          'name': 'Family Support',
          'description': 'Monthly family allowance',
          'amount': 1000.00,
          'currency': 'USD',
          'frequency': 'monthly',
          'nextTransferDate': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 30)),
          ),
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'template_2',
          'name': 'Rent Payment',
          'description': 'Monthly rent payment',
          'amount': 1500.00,
          'currency': 'USD',
          'frequency': 'monthly',
          'nextTransferDate': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 5)),
          ),
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'template_3',
          'name': 'Business Payment',
          'description': 'Supplier payment',
          'amount': 5000.00,
          'currency': 'USD',
          'frequency': 'weekly',
          'nextTransferDate': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 7)),
          ),
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      ];

      for (final template in templates) {
        await templatesRef.doc(template['id'] as String).set(template);
      }

      print('   ✅ Created ${templates.length} transfer templates');
    } else {
      print('   ℹ️ Transfer templates already exist');
    }
  } catch (e) {
    print('   ❌ Error creating transfer templates: $e');
  }
}

Future<void> createTransferFees(FirebaseFirestore firestore) async {
  try {
    final feesRef = firestore.collection('transfer_fees');
    final existingFees = await feesRef.limit(1).get();

    if (existingFees.docs.isEmpty) {
      print('   💰 Creating transfer fees...');

      final fees = [
        {
          'id': 'fee_local',
          'type': 'local',
          'description': 'Local bank transfer within same country',
          'feeType': 'percentage',
          'feeValue': 0.5,
          'minFee': 5.00,
          'maxFee': 50.00,
          'processingTime': '1-2 hours',
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'fee_international',
          'type': 'international',
          'description': 'International wire transfer',
          'feeType': 'percentage',
          'feeValue': 2.0,
          'minFee': 25.00,
          'maxFee': 250.00,
          'processingTime': '2-5 business days',
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'fee_instant',
          'type': 'instant',
          'description': 'Instant transfer',
          'feeType': 'percentage',
          'feeValue': 1.5,
          'minFee': 10.00,
          'maxFee': 100.00,
          'processingTime': '5-30 minutes',
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'fee_same_bank',
          'type': 'same_bank',
          'description': 'Transfer within Alpha Bank',
          'feeType': 'fixed',
          'feeValue': 0.00,
          'minFee': 0.00,
          'maxFee': 0.00,
          'processingTime': 'Instant',
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      ];

      for (final fee in fees) {
        await feesRef.doc(fee['id'] as String).set(fee);
      }

      print('   ✅ Created ${fees.length} transfer fee structures');
    } else {
      print('   ℹ️ Transfer fees already exist');
    }
  } catch (e) {
    print('   ❌ Error creating transfer fees: $e');
  }
}

// ============= DEPOSIT SYSTEM SETUP =============
Future<void> setupDepositSystem() async {
  try {
    final firestore = FirebaseFirestore.instance;

    print('💰 Setting up deposit system...');

    // Create deposit settings
    await createDepositSettings(firestore);

    // Create deposit fees structure
    await createDepositFees(firestore);

    // Create deposit methods
    await createDepositMethods(firestore);

    print('   ✅ Deposit system setup completed\n');
  } catch (e) {
    print('   ❌ Error setting up deposit system: $e');
  }
}

Future<void> createDepositSettings(FirebaseFirestore firestore) async {
  try {
    final settingsRef = firestore.collection('deposit_settings').doc('global');
    final existingSettings = await settingsRef.get();

    if (!existingSettings.exists) {
      print('   ⚙️ Creating deposit settings...');

      await settingsRef.set({
        'general': {
          'defaultCurrency': 'NGN',
          'adminApprovalRequired': true,
          'notificationEmail': ADMIN_EMAIL,
          'adminUid': ADMIN_UID,
          'autoApproveLimit': 10000.00,
          'requiresVerificationAbove': 50000.00,
          'processingTime': '1-24 hours',
          'supportedCurrencies': ['NGN', 'USD', 'EUR', 'GBP'],
          'lastUpdated': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        },
        'limits': {
          'minDepositAmount': 100.00,
          'maxDepositAmount': 1000000.00,
          'dailyDepositLimit': 5000000.00,
          'monthlyDepositLimit': 20000000.00,
          'perTransactionLimit': 1000000.00,
          'requiresAdminApprovalAbove': 100000.00,
        },
        'verification': {
          'requiresIdVerification': true,
          'requiresAddressVerification': false,
          'requiresSourceOfFunds': true,
          'requiresTaxIdForLargeDeposits': true,
          'taxIdThreshold': 1000000.00,
        },
        'notifications': {
          'sendEmailOnDeposit': true,
          'sendPushOnDeposit': true,
          'sendEmailOnApproval': true,
          'sendEmailOnRejection': true,
          'adminEmailOnLargeDeposit': true,
          'largeDepositThreshold': 500000.00,
        },
        'statuses': {
          'pending': 'Pending Admin Approval',
          'processing': 'Processing',
          'completed': 'Completed',
          'rejected': 'Rejected',
          'failed': 'Failed',
          'cancelled': 'Cancelled',
        },
      });

      print('   ✅ Created deposit settings');
    } else {
      print('   ℹ️ Deposit settings already exist');
    }
  } catch (e) {
    print('   ❌ Error creating deposit settings: $e');
  }
}

Future<void> createDepositFees(FirebaseFirestore firestore) async {
  try {
    final feesRef = firestore.collection('deposit_fees');
    final existingFees = await feesRef.limit(1).get();

    if (existingFees.docs.isEmpty) {
      print('   💰 Creating deposit fees...');

      final fees = [
        {
          'id': 'fee_bank_transfer',
          'method': 'bank_transfer',
          'description': 'Bank Transfer Deposit',
          'feeType': 'fixed', // fixed or percentage
          'feeValue': 25.00,
          'minAmount': 100.00,
          'maxAmount': 500000.00,
          'processingTime': '1-24 hours',
          'isActive': true,
          'countries': ['NG', 'US', 'UK', 'CA', 'AU'],
          'currency': 'NGN',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'fee_card',
          'method': 'card',
          'description': 'Credit/Debit Card Deposit',
          'feeType': 'percentage',
          'feeValue': 1.5, // 1.5%
          'minFee': 10.00,
          'maxFee': 250.00,
          'minAmount': 100.00,
          'maxAmount': 500000.00,
          'processingTime': 'Instant - 2 hours',
          'isActive': true,
          'supportedCardTypes': ['Visa', 'Mastercard', 'Verve'],
          'countries': ['NG', 'US', 'UK', 'CA', 'AU'],
          'currency': 'NGN',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'fee_wallet',
          'method': 'wallet',
          'description': 'Mobile Wallet Deposit',
          'feeType': 'percentage',
          'feeValue': 0.5, // 0.5%
          'minFee': 5.00,
          'maxFee': 50.00,
          'minAmount': 100.00,
          'maxAmount': 200000.00,
          'processingTime': 'Instant',
          'isActive': true,
          'supportedWallets': ['PayPal', 'Apple Pay', 'Google Pay'],
          'countries': ['US', 'UK', 'CA', 'AU'],
          'currency': 'USD',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'fee_crypto',
          'method': 'crypto',
          'description': 'Cryptocurrency Deposit',
          'feeType': 'percentage',
          'feeValue': 0.1, // 0.1%
          'minFee': 1.00,
          'maxFee': 100.00,
          'minAmount': 10.00,
          'maxAmount': 1000000.00,
          'processingTime': '5-30 minutes',
          'isActive': false,
          'supportedCryptos': ['Bitcoin', 'Ethereum', 'USDT'],
          'countries': ['US', 'UK', 'CA', 'AU'],
          'currency': 'USD',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      ];

      for (final fee in fees) {
        await feesRef.doc(fee['id'] as String).set(fee);
      }

      print('   ✅ Created ${fees.length} deposit fee structures');
    } else {
      print('   ℹ️ Deposit fees already exist');
    }
  } catch (e) {
    print('   ❌ Error creating deposit fees: $e');
  }
}

Future<void> createDepositMethods(FirebaseFirestore firestore) async {
  try {
    final methodsRef = firestore.collection('deposit_methods');
    final existingMethods = await methodsRef.limit(1).get();

    if (existingMethods.docs.isEmpty) {
      print('   💳 Creating deposit methods...');

      final methods = [
        {
          'id': 'method_bank_transfer',
          'name': 'Bank Transfer',
          'type': 'bank_transfer',
          'description': 'Transfer from any bank account',
          'icon': 'account_balance',
          'color': '#1976D2',
          'isActive': true,
          'priority': 1,
          'minAmount': 100.00,
          'maxAmount': 1000000.00,
          'processingTime': '1-24 hours',
          'requiresAccountDetails': true,
          'requiresAdminApproval': true,
          'bankDetails': {
            'accountName': 'Alpha Bank Nigeria Ltd',
            'accountNumber': '1234567890',
            'bankName': 'Alpha Bank',
            'branch': 'Lagos Main Branch',
            'swiftCode': 'CRBAGRAA',
            'iban': null,
            'routingNumber': null,
            'additionalInstructions': 'Use your User ID as reference',
          },
          'supportedCountries': ['NG', 'US', 'UK', 'CA', 'AU'],
          'supportedCurrencies': ['NGN', 'USD', 'EUR', 'GBP'],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'method_card',
          'name': 'Credit/Debit Card',
          'type': 'card',
          'description': 'Visa, Mastercard, or Verve',
          'icon': 'credit_card',
          'color': '#7B1FA2',
          'isActive': true,
          'priority': 2,
          'minAmount': 100.00,
          'maxAmount': 500000.00,
          'processingTime': 'Instant - 2 hours',
          'requiresCardDetails': true,
          'requiresAdminApproval': false,
          'supportedCardTypes': ['Visa', 'Mastercard', 'Verve'],
          'supportedCountries': ['NG', 'US', 'UK', 'CA', 'AU'],
          'supportedCurrencies': ['NGN', 'USD', 'EUR'],
          'securityFeatures': {
            'requiresCvv': true,
            'requires3DSecure': true,
            'tokenizationEnabled': true,
            'saveCardAllowed': true,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'method_wallet',
          'name': 'Mobile Wallet',
          'type': 'wallet',
          'description': 'PayPal, Apple Pay, Google Pay',
          'icon': 'account_balance_wallet',
          'color': '#2E7D32',
          'isActive': true,
          'priority': 3,
          'minAmount': 100.00,
          'maxAmount': 200000.00,
          'processingTime': 'Instant',
          'requiresWalletId': true,
          'requiresAdminApproval': false,
          'supportedWallets': ['PayPal', 'Apple Pay', 'Google Pay'],
          'supportedCountries': ['US', 'UK', 'CA', 'AU'],
          'supportedCurrencies': ['USD', 'EUR', 'GBP'],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'method_cash',
          'name': 'Cash Deposit',
          'type': 'cash',
          'description': 'Deposit cash at any branch',
          'icon': 'attach_money',
          'color': '#F57C00',
          'isActive': true,
          'priority': 4,
          'minAmount': 100.00,
          'maxAmount': 500000.00,
          'processingTime': '1-2 hours',
          'requiresBranchVisit': true,
          'requiresAdminApproval': true,
          'branches': [
            {
              'name': 'Lagos Main Branch',
              'address': '123 Bank Street, Lagos',
              'phone': '+2341234567890',
              'hours': '9AM - 5PM, Mon-Fri',
            },
            {
              'name': 'Abuja Branch',
              'address': '456 Capital Avenue, Abuja',
              'phone': '+2349876543210',
              'hours': '9AM - 4PM, Mon-Fri',
            },
          ],
          'supportedCountries': ['NG'],
          'supportedCurrencies': ['NGN'],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      ];

      for (final method in methods) {
        await methodsRef.doc(method['id'] as String).set(method);
      }

      print('   ✅ Created ${methods.length} deposit methods');
    } else {
      print('   ℹ️ Deposit methods already exist');
    }
  } catch (e) {
    print('   ❌ Error creating deposit methods: $e');
  }
}

// ============= BANKS AND COUNTRIES SETUP =============
Future<void> setupBanksAndCountries() async {
  try {
    final firestore = FirebaseFirestore.instance;

    print('🏦 Setting up banks and countries for transfers...');

    // Create banks collection
    await createBanksCollection(firestore);

    // Create countries collection
    await createCountriesCollection(firestore);

    // Create sample Alpha Bank users (non-admin)
    await createSampleAlphaUsers(firestore);

    print('   ✅ Banks and countries setup completed\n');
  } catch (e) {
    print('   ❌ Error setting up banks and countries: $e');
  }
}

Future<void> createBanksCollection(FirebaseFirestore firestore) async {
  try {
    final banksRef = firestore.collection('banks');
    final existingBanks = await banksRef.limit(1).get();

    if (existingBanks.docs.isEmpty) {
      print('   🏦 Creating banks collection...');

      final banks = [
        {
          'id': 'bank_1',
          'name': 'Alpha Bank',
          'code': 'ABL',
          'swiftCode': 'CRBAGRAA',
          'icon': 'account_balance',
          'color': '#003366',
          'country': 'Greece',
          'countryCode': 'GR',
          'status': 'active',
          'transferFee': 5.00,
          'processingTime': '1-2 hours',
          'dailyLimit': 100000.00,
          'monthlyLimit': 500000.00,
          'requiresAccountNumber': true,
          'requiresIBAN': true,
          'requiresSWIFT': false,
          'supportedCurrencies': ['USD', 'EUR', 'GBP'],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'bank_2',
          'name': 'Piraeus Bank',
          'code': 'PIR',
          'swiftCode': 'PIRBGRAA',
          'icon': 'business',
          'color': '#2E7D32',
          'country': 'Greece',
          'countryCode': 'GR',
          'status': 'active',
          'transferFee': 7.00,
          'processingTime': '2-4 hours',
          'dailyLimit': 50000.00,
          'monthlyLimit': 250000.00,
          'requiresAccountNumber': true,
          'requiresIBAN': true,
          'requiresSWIFT': false,
          'supportedCurrencies': ['USD', 'EUR'],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'bank_3',
          'name': 'National Bank of Greece',
          'code': 'NBG',
          'swiftCode': 'ETHNGRAA',
          'icon': 'account_balance_wallet',
          'color': '#1976D2',
          'country': 'Greece',
          'countryCode': 'GR',
          'status': 'active',
          'transferFee': 6.00,
          'processingTime': '1-3 hours',
          'dailyLimit': 75000.00,
          'monthlyLimit': 300000.00,
          'requiresAccountNumber': true,
          'requiresIBAN': true,
          'requiresSWIFT': false,
          'supportedCurrencies': ['USD', 'EUR', 'GBP'],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'bank_4',
          'name': 'Eurobank',
          'code': 'EUR',
          'swiftCode': 'ERBKGRAA',
          'icon': 'euro',
          'color': '#7B1FA2',
          'country': 'Greece',
          'countryCode': 'GR',
          'status': 'active',
          'transferFee': 4.50,
          'processingTime': '1-2 hours',
          'dailyLimit': 80000.00,
          'monthlyLimit': 400000.00,
          'requiresAccountNumber': true,
          'requiresIBAN': true,
          'requiresSWIFT': false,
          'supportedCurrencies': ['EUR'],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'bank_5',
          'name': 'Attica Bank',
          'code': 'ATB',
          'swiftCode': 'ATTBGRAA',
          'icon': 'location_city',
          'color': '#F57C00',
          'country': 'Greece',
          'countryCode': 'GR',
          'status': 'active',
          'transferFee': 8.00,
          'processingTime': '2-5 hours',
          'dailyLimit': 30000.00,
          'monthlyLimit': 150000.00,
          'requiresAccountNumber': true,
          'requiresIBAN': true,
          'requiresSWIFT': false,
          'supportedCurrencies': ['USD', 'EUR'],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'bank_6',
          'name': 'Optima Bank',
          'code': 'OPT',
          'swiftCode': 'OPTBGRAA',
          'icon': 'star',
          'color': '#FF9800',
          'country': 'Greece',
          'countryCode': 'GR',
          'status': 'active',
          'transferFee': 3.50,
          'processingTime': 'Instant - 1 hour',
          'dailyLimit': 60000.00,
          'monthlyLimit': 350000.00,
          'requiresAccountNumber': true,
          'requiresIBAN': true,
          'requiresSWIFT': false,
          'supportedCurrencies': ['USD', 'EUR'],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'bank_7',
          'name': 'HSBC Bank',
          'code': 'HSB',
          'swiftCode': 'HSBCGB2L',
          'icon': 'security',
          'color': '#D32F2F',
          'country': 'United Kingdom',
          'countryCode': 'UK',
          'status': 'active',
          'transferFee': 15.00,
          'processingTime': '1-2 business days',
          'dailyLimit': 50000.00,
          'monthlyLimit': 200000.00,
          'requiresAccountNumber': true,
          'requiresIBAN': false,
          'requiresSWIFT': true,
          'supportedCurrencies': ['USD', 'GBP', 'EUR'],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'bank_8',
          'name': 'Aegean Baltic Bank',
          'code': 'ABB',
          'swiftCode': 'AEGE2L',
          'icon': 'anchor',
          'color': '#0288D1',
          'country': 'Greece',
          'countryCode': 'GR',
          'status': 'active',
          'transferFee': 5.50,
          'processingTime': '2-4 hours',
          'dailyLimit': 40000.00,
          'monthlyLimit': 200000.00,
          'requiresAccountNumber': true,
          'requiresIBAN': true,
          'requiresSWIFT': false,
          'supportedCurrencies': ['USD', 'EUR'],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'bank_9',
          'name': 'Citibank Europe PLC',
          'code': 'CIT',
          'swiftCode': 'CITIIE2X',
          'icon': 'attach_money',
          'color': '#00796B',
          'country': 'Ireland',
          'countryCode': 'IE',
          'status': 'active',
          'transferFee': 12.00,
          'processingTime': '1-3 business days',
          'dailyLimit': 100000.00,
          'monthlyLimit': 500000.00,
          'requiresAccountNumber': true,
          'requiresIBAN': true,
          'requiresSWIFT': true,
          'supportedCurrencies': ['USD', 'EUR', 'GBP'],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'bank_10',
          'name': 'City Bank',
          'code': 'CTB',
          'swiftCode': 'CITYUS33',
          'icon': 'business',
          'color': '#388E3C',
          'country': 'United States',
          'countryCode': 'US',
          'status': 'active',
          'transferFee': 10.00,
          'processingTime': '1-2 business days',
          'dailyLimit': 75000.00,
          'monthlyLimit': 300000.00,
          'requiresAccountNumber': true,
          'requiresIBAN': false,
          'requiresSWIFT': true,
          'supportedCurrencies': ['USD'],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      ];

      for (final bank in banks) {
        await banksRef.doc(bank['id'] as String).set(bank);
      }

      print('   ✅ Created ${banks.length} banks');
    } else {
      print('   ℹ️ Banks already exist (${existingBanks.size} found)');
    }
  } catch (e) {
    print('   ❌ Error creating banks: $e');
  }
}

Future<void> createCountriesCollection(FirebaseFirestore firestore) async {
  try {
    final countriesRef = firestore.collection('countries');
    final existingCountries = await countriesRef.limit(1).get();

    if (existingCountries.docs.isEmpty) {
      print('   🌍 Creating countries collection...');

      final countries = [
        {
          'id': 'US',
          'name': 'United States',
          'code': 'US',
          'currency': 'USD',
          'flag': '🇺🇸',
          'exchangeRate': 1.0,
          'baseTransferFee': 25.0,
          'color': '#1976D2',
          'popular': true,
          'defaultSwiftCode': 'CHASUS33',
          'defaultBank': 'Chase Bank',
          'maxTransferLimit': 100000.00,
          'minTransferAmount': 10.00,
          'processingTime': '1-2 business days',
          'supportedTransferTypes': ['SWIFT', 'ACH'],
          'requiresSwift': true,
          'requiresRoutingNumber': true,
          'requiresIban': false,
          'timezone': 'America/New_York',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'UK',
          'name': 'United Kingdom',
          'code': 'UK',
          'currency': 'GBP',
          'flag': '🇬🇧',
          'exchangeRate': 0.79,
          'baseTransferFee': 20.0,
          'color': '#D32F2F',
          'popular': true,
          'defaultSwiftCode': 'BARCGB22',
          'defaultBank': 'Barclays',
          'maxTransferLimit': 100000.00,
          'minTransferAmount': 10.00,
          'processingTime': '1-2 business days',
          'supportedTransferTypes': ['SWIFT', 'FPS'],
          'requiresSwift': true,
          'requiresSortCode': true,
          'requiresIban': true,
          'timezone': 'Europe/London',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'DE',
          'name': 'Germany',
          'code': 'DE',
          'currency': 'EUR',
          'flag': '🇩🇪',
          'exchangeRate': 0.92,
          'baseTransferFee': 18.0,
          'color': '#FFA000',
          'popular': true,
          'defaultSwiftCode': 'DEUTDEFF',
          'defaultBank': 'Deutsche Bank',
          'maxTransferLimit': 100000.00,
          'minTransferAmount': 10.00,
          'processingTime': '1-2 business days',
          'supportedTransferTypes': ['SWIFT', 'SEPA'],
          'requiresSwift': true,
          'requiresIban': true,
          'requiresBic': true,
          'timezone': 'Europe/Berlin',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'CA',
          'name': 'Canada',
          'code': 'CA',
          'currency': 'CAD',
          'flag': '🇨🇦',
          'exchangeRate': 1.35,
          'baseTransferFee': 22.0,
          'color': '#D32F2F',
          'popular': true,
          'defaultSwiftCode': 'BMOCCAM2',
          'defaultBank': 'BMO',
          'maxTransferLimit': 75000.00,
          'minTransferAmount': 10.00,
          'processingTime': '1-3 business days',
          'supportedTransferTypes': ['SWIFT'],
          'requiresSwift': true,
          'requiresTransitNumber': true,
          'requiresInstitutionNumber': true,
          'timezone': 'America/Toronto',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'AU',
          'name': 'Australia',
          'code': 'AU',
          'currency': 'AUD',
          'flag': '🇦🇺',
          'exchangeRate': 1.52,
          'baseTransferFee': 28.0,
          'color': '#2E7D32',
          'popular': true,
          'defaultSwiftCode': 'ANZBAU3M',
          'defaultBank': 'ANZ Bank',
          'maxTransferLimit': 50000.00,
          'minTransferAmount': 10.00,
          'processingTime': '2-4 business days',
          'supportedTransferTypes': ['SWIFT'],
          'requiresSwift': true,
          'requiresBsb': true,
          'requiresAccountNumber': true,
          'timezone': 'Australia/Sydney',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'JP',
          'name': 'Japan',
          'code': 'JP',
          'currency': 'JPY',
          'flag': '🇯🇵',
          'exchangeRate': 148.50,
          'baseTransferFee': 30.0,
          'color': '#F44336',
          'popular': false,
          'defaultSwiftCode': 'SMBCJPJT',
          'defaultBank': 'Sumitomo Mitsui',
          'maxTransferLimit': 30000.00,
          'minTransferAmount': 1000.00,
          'processingTime': '2-5 business days',
          'supportedTransferTypes': ['SWIFT'],
          'requiresSwift': true,
          'requiresBranchCode': true,
          'requiresAccountNumber': true,
          'timezone': 'Asia/Tokyo',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'CN',
          'name': 'China',
          'code': 'CN',
          'currency': 'CNY',
          'flag': '🇨🇳',
          'exchangeRate': 7.18,
          'baseTransferFee': 35.0,
          'color': '#D32F2F',
          'popular': false,
          'defaultSwiftCode': 'ICBKCNBJ',
          'defaultBank': 'ICBC',
          'maxTransferLimit': 50000.00,
          'minTransferAmount': 100.00,
          'processingTime': '3-5 business days',
          'supportedTransferTypes': ['SWIFT'],
          'requiresSwift': true,
          'requiresCNAPS': true,
          'requiresAccountNumber': true,
          'timezone': 'Asia/Shanghai',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'IN',
          'name': 'India',
          'code': 'IN',
          'currency': 'INR',
          'flag': '🇮🇳',
          'exchangeRate': 83.25,
          'baseTransferFee': 15.0,
          'color': '#FF9800',
          'popular': false,
          'defaultSwiftCode': 'HDFCINBB',
          'defaultBank': 'HDFC Bank',
          'maxTransferLimit': 25000.00,
          'minTransferAmount': 10.00,
          'processingTime': '2-4 business days',
          'supportedTransferTypes': ['SWIFT'],
          'requiresSwift': true,
          'requiresIfsc': true,
          'requiresAccountNumber': true,
          'timezone': 'Asia/Kolkata',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'SG',
          'name': 'Singapore',
          'code': 'SG',
          'currency': 'SGD',
          'flag': '🇸🇬',
          'exchangeRate': 1.34,
          'baseTransferFee': 20.0,
          'color': '#D32F2F',
          'popular': false,
          'defaultSwiftCode': 'DBSBSGSG',
          'defaultBank': 'DBS Bank',
          'maxTransferLimit': 50000.00,
          'minTransferAmount': 10.00,
          'processingTime': '1-2 business days',
          'supportedTransferTypes': ['SWIFT'],
          'requiresSwift': true,
          'requiresAccountNumber': true,
          'timezone': 'Asia/Singapore',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'AE',
          'name': 'United Arab Emirates',
          'code': 'AE',
          'currency': 'AED',
          'flag': '🇦🇪',
          'exchangeRate': 3.67,
          'baseTransferFee': 25.0,
          'color': '#00796B',
          'popular': false,
          'defaultSwiftCode': 'NBQAAEAA',
          'defaultBank': 'NBQ',
          'maxTransferLimit': 75000.00,
          'minTransferAmount': 10.00,
          'processingTime': '1-3 business days',
          'supportedTransferTypes': ['SWIFT'],
          'requiresSwift': true,
          'requiresIban': true,
          'requiresAccountNumber': true,
          'timezone': 'Asia/Dubai',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'GR',
          'name': 'Greece',
          'code': 'GR',
          'currency': 'EUR',
          'flag': '🇬🇷',
          'exchangeRate': 0.92,
          'baseTransferFee': 12.0,
          'color': '#0D47A1',
          'popular': true,
          'defaultSwiftCode': 'CRBAGRAA',
          'defaultBank': 'Alpha Bank',
          'maxTransferLimit': 50000.00,
          'minTransferAmount': 10.00,
          'processingTime': '1-2 business days',
          'supportedTransferTypes': ['SWIFT', 'SEPA'],
          'requiresSwift': false,
          'requiresIban': true,
          'requiresAccountNumber': true,
          'timezone': 'Europe/Athens',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'FR',
          'name': 'France',
          'code': 'FR',
          'currency': 'EUR',
          'flag': '🇫🇷',
          'exchangeRate': 0.92,
          'baseTransferFee': 16.0,
          'color': '#1976D2',
          'popular': false,
          'defaultSwiftCode': 'BNPAFRPP',
          'defaultBank': 'BNP Paribas',
          'maxTransferLimit': 60000.00,
          'minTransferAmount': 10.00,
          'processingTime': '1-2 business days',
          'supportedTransferTypes': ['SWIFT', 'SEPA'],
          'requiresSwift': true,
          'requiresIban': true,
          'requiresBic': true,
          'timezone': 'Europe/Paris',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      ];

      for (final country in countries) {
        await countriesRef.doc(country['id'] as String).set(country);
      }

      print('   ✅ Created ${countries.length} countries');
    } else {
      print('   ℹ️ Countries already exist (${existingCountries.size} found)');
    }
  } catch (e) {
    print('   ❌ Error creating countries: $e');
  }
}

Future<void> createSampleAlphaUsers(FirebaseFirestore firestore) async {
  try {
    // Get existing non-admin users
    final usersSnapshot = await firestore
        .collection('users')
        .where('role', isEqualTo: 'user')
        .limit(20)
        .get();

    print('   👥 Found ${usersSnapshot.docs.length} existing users');

    // Create sample recent recipients for each user
    for (final userDoc in usersSnapshot.docs) {
      final userId = userDoc.id;
      await createRecentRecipientsForUser(firestore, userId);
    }

    // Create sample alpha users with more data
    final alphaUsersRef = firestore.collection('alpha_users');
    final existingAlphaUsers = await alphaUsersRef.limit(1).get();

    if (existingAlphaUsers.docs.isEmpty) {
      print('   ➕ Creating sample Alpha users...');

      final sampleAlphaUsers = [
        {
          'id': 'alpha_user_1',
          'userId': 'user_1',
          'name': 'John Alpha',
          'email': 'john.alpha@email.com',
          'phone': '+1234567890',
          'accountNumber': 'ALP-123456',
          'isOnline': true,
          'lastActive': Timestamp.now(),
          'lastActiveText': '2 min ago',
          'avatarColor': '#1976D2',
          'initials': 'JA',
          'balance': 15420.00,
          'balanceFormatted': '\$15,420',
          'isFavorite': true,
          'bank': 'Alpha Bank',
          'joinDate': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 365))),
          'totalTransfers': 45,
          'totalAmount': 125000.00,
          'rating': 4.8,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'alpha_user_2',
          'userId': 'user_2',
          'name': 'Sarah Beta',
          'email': 'sarah.beta@email.com',
          'phone': '+1987654321',
          'accountNumber': 'ALP-789012',
          'isOnline': true,
          'lastActive': Timestamp.now(),
          'lastActiveText': 'Online',
          'avatarColor': '#2E7D32',
          'initials': 'SB',
          'balance': 8250.00,
          'balanceFormatted': '\$8,250',
          'isFavorite': false,
          'bank': 'Alpha Bank',
          'joinDate': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 180))),
          'totalTransfers': 23,
          'totalAmount': 45000.00,
          'rating': 4.5,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'alpha_user_3',
          'userId': 'user_3',
          'name': 'Mike Gamma',
          'email': 'mike.gamma@email.com',
          'phone': '+1122334455',
          'accountNumber': 'ALP-345678',
          'isOnline': false,
          'lastActive': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(hours: 2))),
          'lastActiveText': '2 hours ago',
          'avatarColor': '#FF9800',
          'initials': 'MG',
          'balance': 22500.00,
          'balanceFormatted': '\$22,500',
          'isFavorite': true,
          'bank': 'Alpha Bank',
          'joinDate': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 90))),
          'totalTransfers': 67,
          'totalAmount': 320000.00,
          'rating': 4.9,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'alpha_user_4',
          'userId': 'user_4',
          'name': 'Emma Delta',
          'email': 'emma.delta@email.com',
          'phone': '+1555666777',
          'accountNumber': 'ALP-901234',
          'isOnline': true,
          'lastActive': Timestamp.now(),
          'lastActiveText': 'Online',
          'avatarColor': '#7B1FA2',
          'initials': 'ED',
          'balance': 5800.00,
          'balanceFormatted': '\$5,800',
          'isFavorite': false,
          'bank': 'Alpha Bank',
          'joinDate': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 60))),
          'totalTransfers': 12,
          'totalAmount': 15000.00,
          'rating': 4.2,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'alpha_user_5',
          'userId': 'user_5',
          'name': 'David Omega',
          'email': 'david.omega@email.com',
          'phone': '+1888999000',
          'accountNumber': 'ALP-567890',
          'isOnline': true,
          'lastActive': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(minutes: 5))),
          'lastActiveText': '5 min ago',
          'avatarColor': '#D32F2F',
          'initials': 'DO',
          'balance': 18300.00,
          'balanceFormatted': '\$18,300',
          'isFavorite': true,
          'bank': 'Alpha Bank',
          'joinDate': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 120))),
          'totalTransfers': 34,
          'totalAmount': 89000.00,
          'rating': 4.7,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'alpha_user_6',
          'userId': 'user_6',
          'name': 'Lisa Sigma',
          'email': 'lisa.sigma@email.com',
          'phone': '+1444555666',
          'accountNumber': 'ALP-234567',
          'isOnline': false,
          'lastActive': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 1))),
          'lastActiveText': '1 day ago',
          'avatarColor': '#00796B',
          'initials': 'LS',
          'balance': 12750.00,
          'balanceFormatted': '\$12,750',
          'isFavorite': false,
          'bank': 'Alpha Bank',
          'joinDate': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 30))),
          'totalTransfers': 8,
          'totalAmount': 22000.00,
          'rating': 4.0,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      ];

      for (final user in sampleAlphaUsers) {
        await alphaUsersRef.doc(user['id'] as String).set(user);
      }

      print('   ✅ Created ${sampleAlphaUsers.length} sample Alpha users');
    } else {
      print('   ℹ️ Alpha users already exist');
    }
  } catch (e) {
    print('   ❌ Error creating sample Alpha users: $e');
  }
}

Future<void> createRecentRecipientsForUser(
    FirebaseFirestore firestore, String userId) async {
  try {
    final recipientsRef = firestore
        .collection('users')
        .doc(userId)
        .collection('recent_recipients');
    final existingRecipients = await recipientsRef.limit(1).get();

    if (existingRecipients.docs.isNotEmpty) {
      return;
    }

    print('   📝 Creating recent recipients for user: $userId');

    final recentRecipients = [
      {
        'id': 'recipient_1',
        'name': 'John Doe',
        'account': '123456789012',
        'bank': 'Alpha Bank',
        'bankId': 'bank_1',
        'avatar': 'JD',
        'lastTransfer': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 2))),
        'totalTransfers': 5,
        'totalAmount': 2500.00,
        'isFavorite': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'id': 'recipient_2',
        'name': 'Sarah Smith',
        'account': '432187651098',
        'bank': 'Piraeus Bank',
        'bankId': 'bank_2',
        'avatar': 'SS',
        'lastTransfer': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 7))),
        'totalTransfers': 3,
        'totalAmount': 1500.00,
        'isFavorite': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'id': 'recipient_3',
        'name': 'Mike Johnson',
        'account': '567812340987',
        'bank': 'National Bank of Greece',
        'bankId': 'bank_3',
        'avatar': 'MJ',
        'lastTransfer': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 1))),
        'totalTransfers': 8,
        'totalAmount': 8500.00,
        'isFavorite': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'id': 'recipient_4',
        'name': 'Emma Wilson',
        'account': '876543212109',
        'bank': 'Eurobank',
        'bankId': 'bank_4',
        'avatar': 'EW',
        'lastTransfer': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 14))),
        'totalTransfers': 2,
        'totalAmount': 1000.00,
        'isFavorite': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    ];

    for (final recipient in recentRecipients) {
      await recipientsRef.doc(recipient['id'] as String).set(recipient);
    }

    print('   ✅ Created ${recentRecipients.length} recent recipients');
  } catch (e) {
    print('   ❌ Error creating recent recipients: $e');
  }
}

// ============= LIVE CHAT SYSTEM SETUP =============
Future<void> setupLiveChatSystem() async {
  try {
    final firestore = FirebaseFirestore.instance;

    print('💬 Setting up live chat system...');

    // Create chat agents (admin users who can respond)
    await createChatAgents(firestore);

    // Create chat rooms collection structure
    await createChatRoomsCollection(firestore);

    // Create chat settings
    await createChatSettings(firestore);

    print('   ✅ Live chat system setup completed\n');
  } catch (e) {
    print('   ❌ Error setting up live chat: $e');
  }
}

Future<void> createChatAgents(FirebaseFirestore firestore) async {
  try {
    final agentsRef = firestore.collection('chat_agents');
    final existingAgents = await agentsRef.limit(1).get();

    if (existingAgents.docs.isEmpty) {
      print('   👨‍💼 Creating chat agents...');

      final chatAgents = [
        {
          'id': 'agent_1',
          'name': 'Sarah Johnson',
          'email': 'sarah@alphabank.com',
          'avatar': '👩‍💼',
          'role': 'Senior Support Agent',
          'status': 'online',
          'languages': ['English', 'French'],
          'expertise': ['Accounts', 'Transactions', 'Cards'],
          'rating': 4.9,
          'activeChats': 2,
          'maxChats': 10,
          'available': true,
          'onlineSince': Timestamp.now(),
          'lastActive': Timestamp.now(),
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'agent_2',
          'name': 'Michael Chen',
          'email': 'michael@alphabank.com',
          'avatar': '👨‍💼',
          'role': 'Technical Support',
          'status': 'online',
          'languages': ['English', 'Mandarin'],
          'expertise': ['Security', 'Technical Issues', 'App Support'],
          'rating': 4.8,
          'activeChats': 3,
          'maxChats': 10,
          'available': true,
          'onlineSince': Timestamp.now(),
          'lastActive': Timestamp.now(),
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'id': 'agent_3',
          'name': 'Fatima Ahmed',
          'email': 'fatima@alphabank.com',
          'avatar': '👩‍💻',
          'role': 'Account Specialist',
          'status': 'away',
          'languages': ['English', 'Arabic', 'Swahili'],
          'expertise': ['Accounts', 'Loans', 'Investments'],
          'rating': 4.7,
          'activeChats': 1,
          'maxChats': 10,
          'available': true,
          'onlineSince': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(hours: 1))),
          'lastActive': Timestamp.now(),
          'createdAt': FieldValue.serverTimestamp(),
        },
      ];

      for (final agent in chatAgents) {
        await agentsRef.doc(agent['id'] as String).set(agent);
      }

      print('   ✅ Created ${chatAgents.length} chat agents');
    } else {
      print('   ℹ️ Chat agents already exist');
    }
  } catch (e) {
    print('   ❌ Error creating chat agents: $e');
  }
}

Future<void> createChatRoomsCollection(FirebaseFirestore firestore) async {
  try {
    // This collection will be created per user when they start a chat
    print('   💬 Chat rooms collection will be created per-user as needed');
  } catch (e) {
    print('   ❌ Error setting up chat rooms: $e');
  }
}

Future<void> createChatSettings(FirebaseFirestore firestore) async {
  try {
    final settingsRef = firestore.collection('chat_settings').doc('general');
    final existingSettings = await settingsRef.get();

    if (!existingSettings.exists) {
      print('   ⚙️ Creating chat settings...');

      await settingsRef.set({
        'businessHours': {
          'start': '09:00',
          'end': '18:00',
          'timezone': 'Africa/Lagos',
          'days': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
        },
        'offlineMessage':
            'Our support team is currently offline. Please leave a message and we\'ll get back to you within 24 hours.',
        'autoReplyMessages': [
          {
            'trigger': 'welcome',
            'message':
                'Hello! Thank you for contacting Alpha Bank support. How can I help you today?',
            'delay': 1,
          },
          {
            'trigger': 'waiting',
            'message':
                'Thank you for your patience. An agent will be with you shortly.',
            'delay': 30,
          },
        ],
        'averageWaitTime': 2, // minutes
        'maxWaitTime': 15, // minutes
        'isLiveChatEnabled': true,
        'offlineModeEnabled': true,
        'fileSharingEnabled': true,
        'maxFileSize': 5, // MB
        'allowedFileTypes': ['jpg', 'png', 'pdf', 'txt'],
        'transcriptEnabled': true,
        'ratingEnabled': true,
        'lastUpdated': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('   ✅ Created chat settings');
    } else {
      print('   ℹ️ Chat settings already exist');
    }
  } catch (e) {
    print('   ❌ Error creating chat settings: $e');
  }
}

// ============= ADMIN USER SETUP =============
Future<void> setupAdminUser() async {
  final firestore = FirebaseFirestore.instance;

  print('👑 Setting up admin user...');

  try {
    // Check if admin document exists
    final adminDoc = await firestore.collection('users').doc(ADMIN_UID).get();

    if (adminDoc.exists) {
      print('   ℹ️ Admin user already exists, updating...');

      // Update existing admin
      await firestore.collection('users').doc(ADMIN_UID).update({
        'email': ADMIN_EMAIL,
        'role': 'admin',
        'firstName': 'Admin',
        'lastName': 'User',
        'name': 'Admin User',
        'accountNumber': 'ADMIN001',
        'accountType': 'admin',
        'balance': 0.00,
        'isActive': true,
        'isVerified': true,
        'createdAt':
            adminDoc.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLogin': null,
        'failedLoginAttempts': 0,
        'accountLocked': false,
        'preferredCurrency': 'USD',
        'notificationEnabled': true,
        'biometricEnabled': false,
        'fingerprintEnabled': false,
        'faceIdEnabled': false,
        'registrationStep': 4,
        'username': 'admin',
        'pin': '',
        'secureCode': '',
        'securityQuestions': [],
        'accountLockedUntil': null,
      });

      print('   ✅ Updated admin user');
    } else {
      print('   ➕ Creating new admin user...');

      // Create new admin user
      await firestore.collection('users').doc(ADMIN_UID).set({
        'email': ADMIN_EMAIL,
        'role': 'admin',
        'firstName': 'Admin',
        'lastName': 'User',
        'name': 'Admin User',
        'accountNumber': 'ADMIN001',
        'accountType': 'admin',
        'balance': 0.00,
        'isActive': true,
        'isVerified': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLogin': null,
        'failedLoginAttempts': 0,
        'accountLocked': false,
        'preferredCurrency': 'USD',
        'notificationEnabled': true,
        'biometricEnabled': false,
        'fingerprintEnabled': false,
        'faceIdEnabled': false,
        'registrationStep': 4,
        'username': 'admin',
        'pin': '',
        'secureCode': '',
        'securityQuestions': [],
        'accountLockedUntil': null,
      });

      print('   ✅ Created admin user with UID: $ADMIN_UID');
    }

    // Create admin security settings
    await createSecuritySettings(firestore.collection('users').doc(ADMIN_UID));

    // Create admin notification preferences
    await createNotificationPreferences(
        firestore.collection('users').doc(ADMIN_UID));

    print('   👑 Admin setup completed\n');
  } catch (e) {
    print('   ❌ Error setting up admin: $e');
  }
}

// ============= UPDATE ALL USERS =============
Future<void> updateAllUsers() async {
  final firestore = FirebaseFirestore.instance;

  print('📊 Fetching all users from Firestore...');
  final usersSnapshot = await firestore.collection('users').get();

  if (usersSnapshot.docs.isEmpty) {
    print('⚠️ No users found in Firestore.');
    return;
  }

  print('👥 Found ${usersSnapshot.docs.length} user(s)\n');

  for (var i = 0; i < usersSnapshot.docs.length; i++) {
    final userDoc = usersSnapshot.docs[i];
    final userData = userDoc.data();
    final userId = userDoc.id;
    final email = userData['email'] ?? 'No email';
    final role = userData['role'] ?? 'user';

    // Skip admin as we already processed it
    if (userId == ADMIN_UID) {
      print('${i + 1}. 👑 Skipping admin user');
      continue;
    }

    print('${i + 1}. 👤 Processing: $email ($role)');
    print('   ID: $userId');

    await updateSingleUser(firestore, userDoc.reference, userData, userId);
  }
}

Future<void> updateSingleUser(
  FirebaseFirestore firestore,
  DocumentReference userRef,
  Map<String, dynamic> userData,
  String userId,
) async {
  try {
    final updates = <String, dynamic>{};
    final role = userData['role'] ?? 'user';

    // Check and add missing fields
    if (userData['accountNumber'] == null) {
      updates['accountNumber'] =
          generateAccountNumber(userId, userData['email'] ?? '');
      print('   ➕ Added accountNumber: ${updates['accountNumber']}');
    }

    if (userData['name'] == null) {
      final firstName = userData['firstName'] ?? '';
      final lastName = userData['lastName'] ?? '';
      final name = '$firstName $lastName'.trim();
      updates['name'] = name.isNotEmpty
          ? name
          : userData['email']?.split('@').first ?? 'User';
      print('   ➕ Added name: ${updates['name']}');
    }

    // Ensure role is set
    if (userData['role'] == null) {
      updates['role'] = 'user';
      print('   ➕ Added role: user');
    }

    if (userData['accountType'] == null) {
      updates['accountType'] = role == 'admin' ? 'admin' : 'personal';
      print('   ➕ Added accountType: ${updates['accountType']}');
    }

    // Add balance field if not present (only for non-admin users)
    if (userData['balance'] == null && role != 'admin') {
      final currentBalance = userData['accountBalance'] ?? 10000.00;
      updates['balance'] = currentBalance;
      print('   ➕ Added balance: \$${updates['balance']}');
    }

    // Add security fields
    if (userData['username'] == null) {
      updates['username'] = '';
      print('   ➕ Added username field');
    }

    if (userData['pin'] == null) {
      updates['pin'] = '';
      print('   ➕ Added PIN field');
    }

    if (userData['secureCode'] == null) {
      updates['secureCode'] = '';
      print('   ➕ Added secureCode field');
    }

    if (userData['fingerprintEnabled'] == null) {
      updates['fingerprintEnabled'] = false;
      print('   ➕ Added fingerprintEnabled field');
    }

    if (userData['faceIdEnabled'] == null) {
      updates['faceIdEnabled'] = false;
      print('   ➕ Added faceIdEnabled field');
    }

    if (userData['isVerified'] == null) {
      updates['isVerified'] = role == 'admin' ? true : false;
      print('   ➕ Added isVerified: ${updates['isVerified']}');
    }

    if (userData['registrationStep'] == null) {
      updates['registrationStep'] = role == 'admin' ? 4 : 0;
      print('   ➕ Added registrationStep: ${updates['registrationStep']}');
    }

    if (userData['securityQuestions'] == null) {
      updates['securityQuestions'] = [];
      print('   ➕ Added securityQuestions field');
    }

    if (userData['lastLogin'] == null) {
      updates['lastLogin'] = null;
      print('   ➕ Added lastLogin field');
    }

    if (userData['failedLoginAttempts'] == null) {
      updates['failedLoginAttempts'] = 0;
      print('   ➕ Added failedLoginAttempts field');
    }

    if (userData['accountLocked'] == null) {
      updates['accountLocked'] = false;
      print('   ➕ Added accountLocked field');
    }

    if (userData['accountLockedUntil'] == null) {
      updates['accountLockedUntil'] = null;
      print('   ➕ Added accountLockedUntil field');
    }

    if (userData['preferredCurrency'] == null) {
      updates['preferredCurrency'] = 'USD';
      print('   ➕ Added preferredCurrency field');
    }

    if (userData['notificationEnabled'] == null) {
      updates['notificationEnabled'] = true;
      print('   ➕ Added notificationEnabled field');
    }

    if (userData['biometricEnabled'] == null) {
      updates['biometricEnabled'] = false;
      print('   ➕ Added biometricEnabled field');
    }

    // Add default values for other required fields
    if (userData['isActive'] == null) {
      updates['isActive'] = true;
    }

    if (userData['createdAt'] == null) {
      updates['createdAt'] = FieldValue.serverTimestamp();
    }

    if (userData['updatedAt'] == null) {
      updates['updatedAt'] = FieldValue.serverTimestamp();
    }

    // Update user document with missing fields
    if (updates.isNotEmpty) {
      await userRef.update(updates);
      print('   ✅ Updated user document');
    } else {
      print('   ℹ️ User document already has all fields');
    }

    // Create security settings subcollection
    await createSecuritySettings(userRef);

    // Create notification preferences subcollection
    await createNotificationPreferences(userRef);

    // Create primary account in accounts subcollection (only for non-admin users)
    if (role != 'admin') {
      await createPrimaryAccount(userRef, userData);

      // Create transactions subcollection with deposit/withdrawal transactions
      await createSampleTransactions(userRef, userData);
    }

    print('   ✔️ User update completed\n');
  } catch (e) {
    print('   ❌ Error updating user: $e\n');
  }
}

Future<void> createSecuritySettings(DocumentReference userRef) async {
  try {
    final securityRef = userRef.collection('security_settings').doc('settings');
    final existingSettings = await securityRef.get();

    if (!existingSettings.exists) {
      print('   🔒 Creating security settings...');

      final securitySettings = {
        'pinRetryLimit': 3,
        'sessionTimeout': 30, // minutes
        'autoLockEnabled': true,
        'requirePinForTransactions': true,
        'requirePinForLogin': false,
        'maxTransactionAmount': 10000.00,
        'dailyTransactionLimit': 50000.00,
        'whitelistedDevices': [],
        'loginHistory': [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await securityRef.set(securitySettings);
      print('   ✅ Created security settings');
    } else {
      print('   ℹ️ Security settings already exist');
    }
  } catch (e) {
    print('   ❌ Error creating security settings: $e');
  }
}

Future<void> createNotificationPreferences(DocumentReference userRef) async {
  try {
    final notificationsRef =
        userRef.collection('notifications').doc('preferences');
    final existingPrefs = await notificationsRef.get();

    if (!existingPrefs.exists) {
      print('   🔔 Creating notification preferences...');

      final notificationPrefs = {
        'transactionAlerts': true,
        'securityAlerts': true,
        'promotionalMessages': false,
        'balanceUpdates': true,
        'pushNotifications': true,
        'emailNotifications': true,
        'smsNotifications': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await notificationsRef.set(notificationPrefs);
      print('   ✅ Created notification preferences');
    } else {
      print('   ℹ️ Notification preferences already exist');
    }
  } catch (e) {
    print('   ❌ Error creating notification preferences: $e');
  }
}

Future<void> createPrimaryAccount(
  DocumentReference userRef,
  Map<String, dynamic> userData,
) async {
  try {
    final accountsRef = userRef.collection('accounts');
    final existingAccounts = await accountsRef.limit(1).get();

    if (existingAccounts.docs.isEmpty) {
      print('   📝 Creating primary account...');

      final primaryAccount = {
        'title': 'Alpha Bank Account',
        'accountNumber': userData['accountNumber'] ??
            generateAccountNumber(
                userRef.id, userData['email'] ?? 'user@email.com'),
        'balance':
            userData['balance'] ?? userData['accountBalance'] ?? 10000.00,
        'available':
            userData['balance'] ?? userData['accountBalance'] ?? 10000.00,
        'currencyCode': 'USD',
        'isPrimary': true,
        'status': 'Active',
        'type': 'checking',
        'interestRate': '1.5%',
        'openedDate': FieldValue.serverTimestamp(),
        'lastTransaction': 'Welcome to Alpha Bank',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'securityLevel': 'high',
        'dailyLimit': 5000.00,
        'monthlyLimit': 100000.00,
      };

      await accountsRef.add(primaryAccount);
      print('   ✅ Created primary account');

      // Create additional sample accounts for different currencies
      await createAdditionalAccounts(accountsRef, userData);
    } else {
      print(
          '   ℹ️ Accounts already exist (${existingAccounts.docs.length} found)');
    }
  } catch (e) {
    print('   ❌ Error creating accounts: $e');
  }
}

Future<void> createAdditionalAccounts(
  CollectionReference accountsRef,
  Map<String, dynamic> userData,
) async {
  try {
    final additionalAccounts = [
      {
        'title': 'Pound Sterling Account',
        'accountNumber':
            'GBP-${DateTime.now().millisecondsSinceEpoch.toString().substring(8, 13)}',
        'balance': 5000.00,
        'available': 5000.00,
        'currencyCode': 'GBP',
        'isPrimary': false,
        'status': 'Active',
        'type': 'checking',
        'interestRate': '2.1%',
        'openedDate': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 30))),
        'lastTransaction': 'Deposit received',
        'createdAt': FieldValue.serverTimestamp(),
        'securityLevel': 'medium',
        'dailyLimit': 3000.00,
        'monthlyLimit': 50000.00,
      },
      {
        'title': 'Euro Account',
        'accountNumber':
            'EUR-${DateTime.now().millisecondsSinceEpoch.toString().substring(8, 13)}',
        'balance': 2500.00,
        'available': 2500.00,
        'currencyCode': 'EUR',
        'isPrimary': false,
        'status': 'Active',
        'type': 'checking',
        'interestRate': '0.8%',
        'openedDate': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 15))),
        'lastTransaction': 'Initial deposit',
        'createdAt': FieldValue.serverTimestamp(),
        'securityLevel': 'medium',
        'dailyLimit': 2000.00,
        'monthlyLimit': 30000.00,
      },
      {
        'title': 'Naira Account',
        'accountNumber':
            'NGN-${DateTime.now().millisecondsSinceEpoch.toString().substring(8, 13)}',
        'balance': 500000.00,
        'available': 500000.00,
        'currencyCode': 'NGN',
        'isPrimary': false,
        'status': 'Active',
        'type': 'checking',
        'interestRate': '5.5%',
        'openedDate': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 10))),
        'lastTransaction': 'Local deposit',
        'createdAt': FieldValue.serverTimestamp(),
        'securityLevel': 'low',
        'dailyLimit': 1000000.00,
        'monthlyLimit': 5000000.00,
      },
      {
        'title': 'Savings Account',
        'accountNumber':
            'SAV-${DateTime.now().millisecondsSinceEpoch.toString().substring(8, 13)}',
        'balance': 15000.00,
        'available': 15000.00,
        'currencyCode': 'USD',
        'isPrimary': false,
        'status': 'Active',
        'type': 'savings',
        'interestRate': '3.5%',
        'openedDate': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 60))),
        'lastTransaction': 'Monthly interest',
        'createdAt': FieldValue.serverTimestamp(),
        'securityLevel': 'high',
        'dailyLimit': 10000.00,
        'monthlyLimit': 50000.00,
        'withdrawalLimit': 5000.00,
      },
    ];

    for (final account in additionalAccounts) {
      await accountsRef.add(account);
    }

    print('   ✅ Created ${additionalAccounts.length} additional accounts');
  } catch (e) {
    print('   ❌ Error creating additional accounts: $e');
  }
}

Future<void> createSampleTransactions(
  DocumentReference userRef,
  Map<String, dynamic> userData,
) async {
  try {
    final transactionsRef = userRef.collection('transactions');
    final existingTransactions = await transactionsRef.limit(1).get();

    if (existingTransactions.docs.isNotEmpty) {
      print(
          '   ℹ️ Transactions already exist (${existingTransactions.docs.length} found)');
      return;
    }

    print(
        '   📝 Creating sample transactions with deposits and withdrawals...');

    final userName = userData['name'] ?? userData['email'] ?? 'User';
    final currentBalance = userData['accountBalance'] ?? 10000.00;
    final primaryAccountNumber = userData['accountNumber'] ?? 'ALPHA001';
    final gbpAccount =
        'GBP-${DateTime.now().millisecondsSinceEpoch.toString().substring(8, 13)}';
    final eurAccount =
        'EUR-${DateTime.now().millisecondsSinceEpoch.toString().substring(8, 13)}';
    final ngnAccount =
        'NGN-${DateTime.now().millisecondsSinceEpoch.toString().substring(8, 13)}';

    final sampleTransactions = [
      // Primary account transactions - Deposits
      {
        'amount': 10000.00,
        'description': 'Welcome to Alpha Bank!',
        'type': 'deposit',
        'timestamp': Timestamp.now(),
        'status': 'completed',
        'from': 'Alpha Bank',
        'to': userName,
        'balanceAfter': currentBalance,
        'category': 'banking',
        'accountNumber': primaryAccountNumber,
        'transactionId': 'WELCOME${DateTime.now().millisecondsSinceEpoch}',
        'createdAt': FieldValue.serverTimestamp(),
        'securityLevel': 'low',
        'requiresVerification': false,
        'transactionType': 'deposit',
        'depositDetails': {
          'method': 'bonus',
          'fee': 0.00,
          'total': 10000.00,
          'requiresAdminApproval': false,
          'adminApproved': true,
          'adminApprovedBy': ADMIN_UID,
          'adminApprovedAt': Timestamp.now(),
        }
      },
      {
        'amount': 5000.00,
        'description': 'Salary Deposit',
        'type': 'deposit',
        'timestamp': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 2))),
        'status': 'completed',
        'from': 'ABC Corporation',
        'to': userName,
        'balanceAfter': currentBalance + 5000.00,
        'category': 'income',
        'accountNumber': primaryAccountNumber,
        'transactionId': 'SAL${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        'createdAt': FieldValue.serverTimestamp(),
        'securityLevel': 'low',
        'requiresVerification': false,
        'transactionType': 'deposit',
        'depositDetails': {
          'method': 'bank_transfer',
          'fee': 50.00,
          'total': 5050.00,
          'requiresAdminApproval': true,
          'adminApproved': true,
          'adminNotes': 'Salary deposit verified',
          'adminApprovedBy': ADMIN_UID,
          'adminApprovedAt': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 2))),
        }
      },

      // Primary account transactions - Withdrawals
      {
        'amount': -2500.00,
        'description': 'ATM Withdrawal',
        'type': 'withdrawal',
        'timestamp': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 1))),
        'status': 'completed',
        'from': userName,
        'to': 'Alpha Bank ATM - Lagos Main Branch',
        'balanceAfter': currentBalance + 5000.00 - 2500.00,
        'category': 'cash',
        'accountNumber': primaryAccountNumber,
        'transactionId': 'ATM${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        'createdAt': FieldValue.serverTimestamp(),
        'securityLevel': 'medium',
        'requiresVerification': true,
        'verified': true,
        'transactionType': 'withdrawal',
        'withdrawalDetails': {
          'method': 'atm',
          'fee': 10.00,
          'total': 2510.00,
          'atmLocation': 'Lagos Main Branch',
          'requiresAdminApproval': false,
          'adminApproved': true,
        }
      },
      {
        'amount': -1500.00,
        'description': 'Bank Transfer to John Doe',
        'type': 'withdrawal',
        'timestamp': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 3))),
        'status': 'completed',
        'from': userName,
        'to': 'John Doe',
        'balanceAfter': currentBalance + 5000.00 - 2500.00 - 1500.00,
        'category': 'transfer',
        'accountNumber': primaryAccountNumber,
        'transactionId': 'TRF${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        'createdAt': FieldValue.serverTimestamp(),
        'securityLevel': 'high',
        'requiresVerification': true,
        'verified': true,
        'transactionType': 'withdrawal',
        'withdrawalDetails': {
          'method': 'bank_transfer',
          'fee': 25.00,
          'total': 1525.00,
          'beneficiaryName': 'John Doe',
          'beneficiaryAccount': '1234567890',
          'beneficiaryBank': 'City Bank',
          'requiresAdminApproval': true,
          'adminApproved': true,
          'adminNotes': 'Transfer approved',
          'adminApprovedBy': ADMIN_UID,
          'adminApprovedAt': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 3))),
        }
      },

      // Shopping transactions
      {
        'amount': -450.00,
        'description': 'Amazon Online Shopping',
        'type': 'shopping',
        'timestamp': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 3))),
        'status': 'completed',
        'from': userName,
        'to': 'Amazon Inc',
        'balanceAfter': currentBalance + 5000.00 - 2500.00 - 1500.00 - 450.00,
        'category': 'shopping',
        'accountNumber': primaryAccountNumber,
        'transactionId': 'AMZ${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        'createdAt': FieldValue.serverTimestamp(),
        'securityLevel': 'medium',
        'requiresVerification': true,
        'verified': true,
      },

      // GBP account transactions - Deposits
      {
        'amount': 5000.00,
        'description': 'Pound Sterling Deposit',
        'type': 'deposit',
        'timestamp': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 1))),
        'status': 'completed',
        'from': 'UK Transfer',
        'to': userName,
        'balanceAfter': 5000.00,
        'category': 'transfer',
        'accountNumber': gbpAccount,
        'transactionId': 'GBP${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        'createdAt': FieldValue.serverTimestamp(),
        'securityLevel': 'medium',
        'requiresVerification': true,
        'verified': true,
        'transactionType': 'deposit',
        'depositDetails': {
          'method': 'bank_transfer',
          'fee': 75.00,
          'total': 5075.00,
          'requiresAdminApproval': true,
          'adminApproved': true,
          'adminNotes': 'International transfer approved',
          'adminApprovedBy': ADMIN_UID,
          'adminApprovedAt': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 1))),
        }
      },

      // GBP account transactions - Withdrawals
      {
        'amount': -1000.00,
        'description': 'GBP Withdrawal',
        'type': 'withdrawal',
        'timestamp': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 2))),
        'status': 'pending',
        'from': userName,
        'to': 'International Transfer',
        'balanceAfter': 4000.00,
        'category': 'transfer',
        'accountNumber': gbpAccount,
        'transactionId': 'GBPW${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        'createdAt': FieldValue.serverTimestamp(),
        'securityLevel': 'high',
        'requiresVerification': true,
        'transactionType': 'withdrawal',
        'withdrawalDetails': {
          'method': 'bank_transfer',
          'fee': 15.00,
          'total': 1015.00,
          'beneficiaryName': 'International Client',
          'beneficiaryAccount': 'GB29NWBK60161331926819',
          'beneficiaryBank': 'UK Bank',
          'requiresAdminApproval': true,
          'adminApproved': false,
          'adminNotes': 'Pending review',
        }
      },

      // EUR account transactions - Deposits
      {
        'amount': 3000.00,
        'description': 'Euro Deposit',
        'type': 'deposit',
        'timestamp': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 2))),
        'status': 'completed',
        'from': 'EU Bank',
        'to': userName,
        'balanceAfter': 3000.00,
        'category': 'transfer',
        'accountNumber': eurAccount,
        'transactionId': 'EUR${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        'createdAt': FieldValue.serverTimestamp(),
        'securityLevel': 'medium',
        'requiresVerification': true,
        'verified': true,
        'transactionType': 'deposit',
        'depositDetails': {
          'method': 'bank_transfer',
          'fee': 45.00,
          'total': 3045.00,
          'requiresAdminApproval': true,
          'adminApproved': true,
          'adminNotes': 'EU transfer approved',
          'adminApprovedBy': ADMIN_UID,
          'adminApprovedAt': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 2))),
        }
      },

      // NGN account transactions - Deposits
      {
        'amount': 500000.00,
        'description': 'Naira Deposit',
        'type': 'deposit',
        'timestamp': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 5))),
        'status': 'completed',
        'from': 'Local Transfer',
        'to': userName,
        'balanceAfter': 500000.00,
        'category': 'transfer',
        'accountNumber': ngnAccount,
        'transactionId': 'NGN${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        'createdAt': FieldValue.serverTimestamp(),
        'securityLevel': 'low',
        'requiresVerification': false,
        'transactionType': 'deposit',
        'depositDetails': {
          'method': 'bank_transfer',
          'fee': 50.00,
          'total': 500050.00,
          'requiresAdminApproval': true,
          'adminApproved': true,
          'adminNotes': 'Local deposit approved',
          'adminApprovedBy': ADMIN_UID,
          'adminApprovedAt': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 5))),
        }
      },

      // NGN account transactions - Withdrawals
      {
        'amount': -100000.00,
        'description': 'Cash Withdrawal',
        'type': 'withdrawal',
        'timestamp': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 4))),
        'status': 'completed',
        'from': userName,
        'to': 'Alpha Bank Branch',
        'balanceAfter': 400000.00,
        'category': 'cash',
        'accountNumber': ngnAccount,
        'transactionId': 'NGNW${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        'createdAt': FieldValue.serverTimestamp(),
        'securityLevel': 'medium',
        'requiresVerification': true,
        'verified': true,
        'transactionType': 'withdrawal',
        'withdrawalDetails': {
          'method': 'cash',
          'fee': 100.00,
          'total': 100100.00,
          'branchLocation': 'Alpha Bank Lagos Branch',
          'requiresAdminApproval': false,
          'adminApproved': true,
        }
      },

      // Sample exchange transactions
      {
        'amount': -1000.00,
        'description': 'Exchange to GBP',
        'type': 'exchange',
        'timestamp': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 4))),
        'status': 'completed',
        'from': 'USD',
        'to': 'GBP',
        'convertedAmount': 790.00,
        'exchangeRate': 0.79,
        'category': 'exchange',
        'accountNumber': primaryAccountNumber,
        'transactionId': 'EXC${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        'createdAt': FieldValue.serverTimestamp(),
        'securityLevel': 'high',
        'requiresVerification': true,
        'verified': true,
      },
      {
        'amount': 790.00,
        'description': 'Exchange from USD',
        'type': 'deposit',
        'timestamp': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 4))),
        'status': 'completed',
        'from': 'Currency Exchange',
        'to': userName,
        'category': 'exchange',
        'accountNumber': gbpAccount,
        'transactionId': 'EXC${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        'createdAt': FieldValue.serverTimestamp(),
        'securityLevel': 'high',
        'requiresVerification': true,
        'verified': true,
        'transactionType': 'deposit',
        'depositDetails': {
          'method': 'exchange',
          'fee': 10.00,
          'total': 800.00,
          'exchangeRate': 0.79,
          'requiresAdminApproval': false,
          'adminApproved': true,
        }
      },

      // Pending deposit transaction
      {
        'amount': 10000.00,
        'description': 'Business Payment Deposit',
        'type': 'deposit',
        'timestamp': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(hours: 6))),
        'status': 'pending',
        'from': 'Business Client',
        'to': userName,
        'category': 'business',
        'accountNumber': primaryAccountNumber,
        'transactionId': 'PEND${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        'createdAt': FieldValue.serverTimestamp(),
        'securityLevel': 'high',
        'requiresVerification': true,
        'transactionType': 'deposit',
        'depositDetails': {
          'method': 'bank_transfer',
          'fee': 50.00,
          'total': 10050.00,
          'requiresAdminApproval': true,
          'adminApproved': false,
          'adminNotes': 'Awaiting verification',
        }
      },

      // Rejected withdrawal transaction
      {
        'amount': -50000.00,
        'description': 'Large Cash Withdrawal',
        'type': 'withdrawal',
        'timestamp': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 1))),
        'status': 'rejected',
        'from': userName,
        'to': 'Bank Branch',
        'category': 'cash',
        'accountNumber': ngnAccount,
        'transactionId': 'REJ${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        'createdAt': FieldValue.serverTimestamp(),
        'securityLevel': 'high',
        'requiresVerification': true,
        'verified': false,
        'transactionType': 'withdrawal',
        'withdrawalDetails': {
          'method': 'cash',
          'fee': 0.00,
          'total': 50000.00,
          'branchLocation': 'Main Branch',
          'requiresAdminApproval': true,
          'adminApproved': false,
          'adminNotes': 'Rejected: Exceeds daily limit',
          'adminApprovedBy': ADMIN_UID,
          'adminApprovedAt': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 1))),
        }
      },
    ];

    // Add all transactions
    for (final transaction in sampleTransactions) {
      await transactionsRef.add(transaction);
    }

    print(
        '   ✅ Created ${sampleTransactions.length} sample transactions with deposits and withdrawals');

    // Update lastTransaction in accounts
    await updateAccountsLastTransaction(userRef, sampleTransactions);
  } catch (e) {
    print('   ❌ Error creating transactions: $e');
  }
}

// ============= EXCHANGE RATES SETUP =============
Future<void> updateExchangeRates() async {
  try {
    final firestore = FirebaseFirestore.instance;

    print('💱 Checking exchange rates collection...');

    // Get all existing exchange rates
    final existingRates = await firestore.collection('exchange_rates').get();

    if (existingRates.docs.isEmpty) {
      print('   📊 No exchange rates found, creating...');

      // Create exchange rates as individual documents for easier querying
      final exchangeRates = [
        {
          'baseCurrency': 'USD',
          'targetCurrency': 'EUR',
          'rate': 0.92,
          'commission': 0.01,
          'lastUpdated': FieldValue.serverTimestamp(),
          'updatedBy': ADMIN_UID,
          'isActive': true,
          'minAmount': 10.00,
          'maxAmount': 100000.00,
        },
        {
          'baseCurrency': 'USD',
          'targetCurrency': 'GBP',
          'rate': 0.79,
          'commission': 0.01,
          'lastUpdated': FieldValue.serverTimestamp(),
          'updatedBy': ADMIN_UID,
          'isActive': true,
          'minAmount': 10.00,
          'maxAmount': 100000.00,
        },
        {
          'baseCurrency': 'USD',
          'targetCurrency': 'NGN',
          'rate': 1500.0,
          'commission': 0.02,
          'lastUpdated': FieldValue.serverTimestamp(),
          'updatedBy': ADMIN_UID,
          'isActive': true,
          'minAmount': 10.00,
          'maxAmount': 50000.00,
        },
        {
          'baseCurrency': 'EUR',
          'targetCurrency': 'USD',
          'rate': 1.09,
          'commission': 0.01,
          'lastUpdated': FieldValue.serverTimestamp(),
          'updatedBy': ADMIN_UID,
          'isActive': true,
          'minAmount': 10.00,
          'maxAmount': 100000.00,
        },
        {
          'baseCurrency': 'GBP',
          'targetCurrency': 'USD',
          'rate': 1.27,
          'commission': 0.01,
          'lastUpdated': FieldValue.serverTimestamp(),
          'updatedBy': ADMIN_UID,
          'isActive': true,
          'minAmount': 10.00,
          'maxAmount': 100000.00,
        },
        {
          'baseCurrency': 'NGN',
          'targetCurrency': 'USD',
          'rate': 0.00067,
          'commission': 0.03,
          'lastUpdated': FieldValue.serverTimestamp(),
          'updatedBy': ADMIN_UID,
          'isActive': true,
          'minAmount': 1000.00,
          'maxAmount': 5000000.00,
        },
      ];

      for (final rate in exchangeRates) {
        await firestore.collection('exchange_rates').add(rate);
      }

      print('   ✅ Created ${exchangeRates.length} exchange rates');
    } else {
      print('   ℹ️ Exchange rates already exist (${existingRates.size} found)');

      // Update existing rates with commission and limits if missing
      for (final rateDoc in existingRates.docs) {
        final updates = <String, dynamic>{};
        final data = rateDoc.data();

        if (data['commission'] == null) {
          updates['commission'] = 0.01;
        }

        if (data['minAmount'] == null) {
          updates['minAmount'] = 10.00;
        }

        if (data['maxAmount'] == null) {
          updates['maxAmount'] = 100000.00;
        }

        if (data['updatedBy'] == null) {
          updates['updatedBy'] = ADMIN_UID;
        }

        if (data['isActive'] == null) {
          updates['isActive'] = true;
        }

        if (updates.isNotEmpty) {
          updates['lastUpdated'] = FieldValue.serverTimestamp();
          await rateDoc.reference.update(updates);
        }
      }

      print('   ✅ Updated ${existingRates.size} exchange rates');
    }
  } catch (e) {
    print('   ❌ Error updating exchange rates: $e');
  }
}

// ============= EXCHANGE HISTORY SETUP =============
Future<void> setupExchangeHistory() async {
  try {
    final firestore = FirebaseFirestore.instance;

    print('📜 Setting up exchange history...');

    // Check if exchange_history collection exists and has data
    final historySnapshot =
        await firestore.collection('exchange_history').limit(1).get();

    if (historySnapshot.docs.isEmpty) {
      print('   ➕ Creating sample exchange history...');

      // Create sample exchange history
      final sampleHistory = [
        {
          'userId': ADMIN_UID,
          'userEmail': ADMIN_EMAIL,
          'fromCurrency': 'USD',
          'toCurrency': 'EUR',
          'amount': 1000.00,
          'rate': 0.92,
          'commission': 10.00,
          'total': 910.00,
          'timestamp': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 5))),
          'status': 'completed',
          'transactionId': 'EXH001',
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'userId': ADMIN_UID,
          'userEmail': ADMIN_EMAIL,
          'fromCurrency': 'EUR',
          'toCurrency': 'USD',
          'amount': 500.00,
          'rate': 1.09,
          'commission': 5.45,
          'total': 539.55,
          'timestamp': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 3))),
          'status': 'completed',
          'transactionId': 'EXH002',
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'userId': ADMIN_UID,
          'userEmail': ADMIN_EMAIL,
          'fromCurrency': 'USD',
          'toCurrency': 'NGN',
          'amount': 200.00,
          'rate': 1500.0,
          'commission': 6.00,
          'total': 294000.00,
          'timestamp': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 1))),
          'status': 'completed',
          'transactionId': 'EXH003',
          'createdAt': FieldValue.serverTimestamp(),
        },
      ];

      for (final history in sampleHistory) {
        await firestore.collection('exchange_history').add(history);
      }

      print('   ✅ Created ${sampleHistory.length} exchange history records');
    } else {
      print(
          '   ℹ️ Exchange history already exists (${historySnapshot.size} found)');
    }
  } catch (e) {
    print('   ❌ Error setting up exchange history: $e');
  }
}

// ============= CARDS COLLECTION SETUP =============
Future<void> setupCardsCollection() async {
  try {
    final firestore = FirebaseFirestore.instance;

    print('💳 Setting up cards collection...');

    // Get all users (non-admin)
    final usersSnapshot = await firestore
        .collection('users')
        .where('role', isNotEqualTo: 'admin')
        .get();

    print('   👥 Found ${usersSnapshot.docs.length} users to create cards for');

    for (final userDoc in usersSnapshot.docs) {
      final userId = userDoc.id;
      final userData = userDoc.data();

      print('   👤 Creating cards for user: ${userData['email'] ?? userId}');

      await createUserCards(userId, userData);
    }

    print('✅ Cards setup completed successfully!');
  } catch (e) {
    print('❌ Error setting up cards: $e');
  }
}

Future<void> createUserCards(
    String userId, Map<String, dynamic> userData) async {
  try {
    final firestore = FirebaseFirestore.instance;
    final cardsRef =
        firestore.collection('users').doc(userId).collection('cards');

    // Check if user already has cards
    final existingCards = await cardsRef.limit(1).get();

    if (existingCards.docs.isNotEmpty) {
      print('   ℹ️ User already has cards, updating existing ones...');
      await updateExistingCards(cardsRef, userData);
      return;
    }

    print('   ➕ Creating new cards for user...');

    final userName = userData['name'] ??
        (() {
          final firstName = userData['firstName'] ?? '';
          final lastName = userData['lastName'] ?? '';
          final fullName = '$firstName $lastName'.trim();
          return fullName.isNotEmpty
              ? fullName
              : userData['email']?.split('@').first ?? 'User';
        })();

    // Create sample cards
    final sampleCards = [
      {
        'id': 'card_1',
        'cardNumber': '4234567890121234',
        'maskedCardNumber': '**** **** **** 1234',
        'cardHolder': userName.toUpperCase(),
        'expiryDate': '08/25',
        'expiryMonth': '08',
        'expiryYear': '2025',
        'cvv': '123',
        'maskedCvv': '***',
        'type': 'visa',
        'color': '#003366',
        'isVirtual': true,
        'balance': 50000.00,
        'dailyLimit': 100000.00,
        'monthlyLimit': 500000.00,
        'transactionLimit': 50000.00,
        'spentToday': 45250.00,
        'spentThisMonth': 152840.00,
        'status': 'active',
        'isPrimary': true,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'currency': 'NGN',
        'bankName': 'Alpha Bank',
        'cardType': 'debit',
        'issuer': 'Alpha Bank Nigeria',
        'billingAddress': userData['address'] ?? 'Lagos, Nigeria',
        'activationDate': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 90))),
        'nextStatementDate':
            Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
        'paymentDueDate':
            Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
        'minimumPayment': 0.00,
        'statementBalance': 50000.00,
        'availableCredit': 50000.00,
        'rewardPoints': 1250,
        'cardNetwork': 'Visa',
        'cardTier': 'platinum',
        'contactlessEnabled': true,
        'onlinePaymentsEnabled': true,
        'internationalTransactionsEnabled': true,
        'atmWithdrawalsEnabled': true,
        'pinSet': true,
        'securityFeatures': {
          'transactionAlerts': true,
          'spendingControls': true,
          'locationBasedSecurity': true,
          'biometricAuthentication': false,
        },
        'design': {
          'backgroundImage': null,
          'customText': null,
          'theme': 'default',
        },
      },
      {
        'id': 'card_2',
        'cardNumber': '5234567890125678',
        'maskedCardNumber': '**** **** **** 5678',
        'cardHolder': userName.toUpperCase(),
        'expiryDate': '12/26',
        'expiryMonth': '12',
        'expiryYear': '2026',
        'cvv': '456',
        'maskedCvv': '***',
        'type': 'mastercard',
        'color': '#0d47a1',
        'isVirtual': false,
        'balance': 75000.00,
        'dailyLimit': 150000.00,
        'monthlyLimit': 1000000.00,
        'transactionLimit': 75000.00,
        'spentToday': 0.00,
        'spentThisMonth': 245600.00,
        'status': 'active',
        'isPrimary': false,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'currency': 'NGN',
        'bankName': 'Alpha Bank',
        'cardType': 'credit',
        'creditLimit': 200000.00,
        'availableCredit': 125000.00,
        'issuer': 'Alpha Bank Nigeria',
        'billingAddress': userData['address'] ?? 'Lagos, Nigeria',
        'activationDate': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 60))),
        'nextStatementDate':
            Timestamp.fromDate(DateTime.now().add(const Duration(days: 14))),
        'paymentDueDate':
            Timestamp.fromDate(DateTime.now().add(const Duration(days: 14))),
        'minimumPayment': 5000.00,
        'statementBalance': 75000.00,
        'rewardPoints': 2500,
        'cardNetwork': 'Mastercard',
        'cardTier': 'world',
        'contactlessEnabled': true,
        'onlinePaymentsEnabled': true,
        'internationalTransactionsEnabled': true,
        'atmWithdrawalsEnabled': true,
        'pinSet': true,
        'securityFeatures': {
          'transactionAlerts': true,
          'spendingControls': true,
          'locationBasedSecurity': true,
          'biometricAuthentication': true,
        },
        'design': {
          'backgroundImage': null,
          'customText': null,
          'theme': 'blue',
        },
      },
      {
        'id': 'card_3',
        'cardNumber': '4234567890129012',
        'maskedCardNumber': '**** **** **** 9012',
        'cardHolder': userName.toUpperCase(),
        'expiryDate': '03/25',
        'expiryMonth': '03',
        'expiryYear': '2025',
        'cvv': '789',
        'maskedCvv': '***',
        'type': 'visa',
        'color': '#37474f',
        'isVirtual': true,
        'balance': 25000.00,
        'dailyLimit': 50000.00,
        'monthlyLimit': 250000.00,
        'transactionLimit': 25000.00,
        'spentToday': 12500.00,
        'spentThisMonth': 87500.00,
        'status': 'frozen',
        'isPrimary': false,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'currency': 'USD',
        'bankName': 'Alpha Bank International',
        'cardType': 'debit',
        'issuer': 'Alpha Bank International',
        'billingAddress': 'New York, USA',
        'activationDate': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 30))),
        'nextStatementDate':
            Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
        'paymentDueDate':
            Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
        'minimumPayment': 0.00,
        'statementBalance': 25000.00,
        'availableCredit': 25000.00,
        'rewardPoints': 500,
        'cardNetwork': 'Visa',
        'cardTier': 'signature',
        'contactlessEnabled': true,
        'onlinePaymentsEnabled': true,
        'internationalTransactionsEnabled': true,
        'atmWithdrawalsEnabled': false,
        'pinSet': true,
        'frozenAt': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 2))),
        'freezeReason': 'suspicious_activity',
        'securityFeatures': {
          'transactionAlerts': true,
          'spendingControls': false,
          'locationBasedSecurity': false,
          'biometricAuthentication': false,
        },
        'design': {
          'backgroundImage': null,
          'customText': null,
          'theme': 'dark',
        },
      },
    ];

    // Add card transactions
    for (final card in sampleCards) {
      final cardId = card['id'] as String;
      final cardDocRef = cardsRef.doc(cardId);
      await cardDocRef.set(card);

      // Create card transactions subcollection
      await createCardTransactions(cardDocRef, card);
    }

    print('   ✅ Created ${sampleCards.length} cards for user');
  } catch (e) {
    print('   ❌ Error creating cards: $e');
  }
}

Future<void> updateExistingCards(
    CollectionReference cardsRef, Map<String, dynamic> userData) async {
  try {
    final cardsSnapshot = await cardsRef.get();

    for (final cardDoc in cardsSnapshot.docs) {
      final cardData = cardDoc.data() as Map<String, dynamic>;

      final updates = <String, dynamic>{};

      // Add missing fields to existing cards
      if (cardData['maskedCardNumber'] == null &&
          cardData['cardNumber'] != null) {
        final cardNumber = cardData['cardNumber'].toString();
        if (cardNumber.length >= 4) {
          updates['maskedCardNumber'] =
              '**** **** **** ${cardNumber.substring(cardNumber.length - 4)}';
        }
      }

      if (cardData['maskedCvv'] == null) {
        updates['maskedCvv'] = '***';
      }

      if (cardData['dailyLimit'] == null) {
        updates['dailyLimit'] = 100000.00;
      }

      if (cardData['monthlyLimit'] == null) {
        updates['monthlyLimit'] = 500000.00;
      }

      if (cardData['transactionLimit'] == null) {
        updates['transactionLimit'] = 50000.00;
      }

      if (cardData['spentToday'] == null) {
        updates['spentToday'] = 0.00;
      }

      if (cardData['spentThisMonth'] == null) {
        updates['spentThisMonth'] = 0.00;
      }

      if (cardData['currency'] == null) {
        updates['currency'] = 'NGN';
      }

      if (cardData['bankName'] == null) {
        updates['bankName'] = 'Alpha Bank';
      }

      if (cardData['cardType'] == null) {
        updates['cardType'] = 'debit';
      }

      if (cardData['securityFeatures'] == null) {
        updates['securityFeatures'] = {
          'transactionAlerts': true,
          'spendingControls': true,
          'locationBasedSecurity': false,
          'biometricAuthentication': false,
        };
      }

      if (cardData['design'] == null) {
        updates['design'] = {
          'backgroundImage': null,
          'customText': null,
          'theme': 'default',
        };
      }

      if (updates.isNotEmpty) {
        updates['updatedAt'] = Timestamp.now();
        await cardDoc.reference.update(updates);
      }
    }

    print('   ✅ Updated ${cardsSnapshot.docs.length} existing cards');
  } catch (e) {
    print('   ❌ Error updating cards: $e');
  }
}

Future<void> createCardTransactions(
    DocumentReference cardRef, Map<String, dynamic> cardData) async {
  try {
    final transactionsRef = cardRef.collection('transactions');
    final existingTransactions = await transactionsRef.limit(1).get();

    if (existingTransactions.docs.isNotEmpty) {
      return;
    }

    final cardId = cardData['id'] as String;
    final cardBalance = (cardData['balance'] as num).toDouble();
    final currency = cardData['currency'] as String? ?? 'NGN';

    final sampleTransactions = [
      {
        'id': '${cardId}_trans_1',
        'amount': -15250.00,
        'description': 'Amazon Purchase',
        'merchant': 'Amazon Inc.',
        'merchantCategory': 'E-commerce',
        'type': 'purchase',
        'timestamp': Timestamp.now(),
        'status': 'completed',
        'currency': currency,
        'location': 'Online',
        'country': 'US',
        'isInternational': true,
        'authCode': 'AUTH123456',
        'referenceNumber': 'REF789012',
        'balanceAfter': cardBalance - 15250.00,
        'category': 'shopping',
        'tags': ['online', 'e-commerce'],
        'notes': '',
        'receiptUrl': null,
        'createdAt': Timestamp.now(),
      },
      {
        'id': '${cardId}_trans_2',
        'amount': -3500.00,
        'description': 'Netflix Subscription',
        'merchant': 'Netflix',
        'merchantCategory': 'Entertainment',
        'type': 'subscription',
        'timestamp': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 2))),
        'status': 'completed',
        'currency': currency,
        'location': 'Online',
        'country': 'US',
        'isInternational': true,
        'authCode': 'AUTH789012',
        'referenceNumber': 'REF345678',
        'balanceAfter': cardBalance - 18750.00,
        'category': 'entertainment',
        'tags': ['subscription', 'recurring'],
        'notes': 'Monthly subscription',
        'receiptUrl': null,
        'createdAt': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 2))),
      },
      {
        'id': '${cardId}_trans_3',
        'amount': -8750.00,
        'description': 'Grocery Store',
        'merchant': 'SuperMart',
        'merchantCategory': 'Groceries',
        'type': 'purchase',
        'timestamp': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 3))),
        'status': 'completed',
        'currency': currency,
        'location': 'Lagos, Nigeria',
        'country': 'NG',
        'isInternational': false,
        'authCode': 'AUTH456789',
        'referenceNumber': 'REF901234',
        'balanceAfter': cardBalance - 27500.00,
        'category': 'groceries',
        'tags': ['food', 'essential'],
        'notes': 'Weekly groceries',
        'receiptUrl': null,
        'createdAt': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 3))),
      },
      {
        'id': '${cardId}_trans_4',
        'amount': -5000.00,
        'description': 'ATM Withdrawal',
        'merchant': 'Alpha Bank ATM',
        'merchantCategory': 'ATM',
        'type': 'withdrawal',
        'timestamp': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 5))),
        'status': 'completed',
        'currency': currency,
        'location': 'Lagos Main Branch',
        'country': 'NG',
        'isInternational': false,
        'authCode': 'ATM123456',
        'referenceNumber': 'ATM789012',
        'balanceAfter': cardBalance - 32500.00,
        'category': 'cash',
        'tags': ['atm', 'cash'],
        'notes': '',
        'receiptUrl': null,
        'atmFee': 0.00,
        'createdAt': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 5))),
      },
      {
        'id': '${cardId}_trans_5',
        'amount': 25000.00,
        'description': 'Salary Credit',
        'merchant': 'ABC Corporation',
        'merchantCategory': 'Salary',
        'type': 'deposit',
        'timestamp': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 7))),
        'status': 'completed',
        'currency': currency,
        'location': 'Bank Transfer',
        'country': 'NG',
        'isInternational': false,
        'authCode': 'CREDIT123',
        'referenceNumber': 'SALARY789',
        'balanceAfter': cardBalance - 7500.00,
        'category': 'income',
        'tags': ['salary', 'credit'],
        'notes': 'Monthly salary',
        'receiptUrl': null,
        'createdAt': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 7))),
      },
    ];

    for (final transaction in sampleTransactions) {
      await transactionsRef.doc(transaction['id'] as String).set(transaction);
    }

    print('   💳 Created ${sampleTransactions.length} card transactions');
  } catch (e) {
    print('   ❌ Error creating card transactions: $e');
  }
}

// ============= HELPER FUNCTIONS =============
Future<void> updateAccountsLastTransaction(
  DocumentReference userRef,
  List<Map<String, dynamic>> transactions,
) async {
  try {
    final accountsRef = userRef.collection('accounts');
    final accountsSnapshot = await accountsRef.get();

    for (final accountDoc in accountsSnapshot.docs) {
      final accountData = accountDoc.data();
      final accountNumber = accountData['accountNumber'];

      // Find the latest transaction for this account
      final accountTransactions = transactions
          .where((t) => t['accountNumber'] == accountNumber)
          .toList();

      if (accountTransactions.isNotEmpty) {
        accountTransactions.sort((a, b) => (b['timestamp'] as Timestamp)
            .compareTo(a['timestamp'] as Timestamp));
        final latestTransaction = accountTransactions.first;

        await accountDoc.reference.update({
          'lastTransaction': latestTransaction['description'],
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    print('   ✅ Updated last transaction for all accounts');
  } catch (e) {
    print('   ❌ Error updating accounts last transaction: $e');
  }
}

String generateAccountNumber(String userId, String email) {
  // Generate a readable account number
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final hash = userId.hashCode.abs();

  if (email.contains('alpha') || email.contains('bank')) {
    return 'ALPHA${(timestamp % 1000000).toString().padLeft(6, '0')}';
  } else {
    final namePart = email.split('@').first.toUpperCase();
    final numbers = (hash % 1000000).toString().padLeft(6, '0');
    return 'ACC${namePart.substring(0, min(3, namePart.length))}$numbers';
  }
}

int min(int a, int b) => a < b ? a : b;
