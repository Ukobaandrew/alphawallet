// lib/presentation/pages/auth/user_code_screen.dart
import 'package:flutter/material.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/shared_prefs_service.dart';
import '../../../data/models/user_model.dart';

class UserCodeScreen extends StatefulWidget {
  const UserCodeScreen({super.key});

  @override
  _UserCodeScreenState createState() => _UserCodeScreenState();
}

class _UserCodeScreenState extends State<UserCodeScreen> {
  final TextEditingController _codeController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _verifyUserCode() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your registration code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final user = await _firebaseService.getUserByCode(code);

      if (user == null) {
        setState(() {
          _errorMessage = 'Invalid registration code. Please check with admin.';
          _isLoading = false;
        });
        return;
      }

      if (user.status != UserStatus.pending) {
        setState(() {
          _errorMessage = 'This account is already registered or blocked.';
          _isLoading = false;
        });
        return;
      }

      // Store user code and navigate to registration
      await SharedPrefsService().setUserCode(code);

      Navigator.pushReplacementNamed(
        context,
        '/register',
        arguments: {'user': user},
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
              ),

              const SizedBox(height: 40),

              // Title
              const Text(
                'Enter Registration Code',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Enter the registration code provided by your administrator',
                style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
              ),

              const SizedBox(height: 40),

              // Code Input
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Enter your code',
                    hintStyle: TextStyle(color: Colors.grey),
                    suffixIcon: Icon(Icons.vpn_key, color: Colors.blue),
                  ),
                  style: const TextStyle(fontSize: 18),
                  onChanged: (_) {
                    if (_errorMessage.isNotEmpty) {
                      setState(() {
                        _errorMessage = '';
                      });
                    }
                  },
                  onSubmitted: (_) => _verifyUserCode(),
                ),
              ),

              // Error Message
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ),

              const SizedBox(height: 20),

              // Instructions
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'How to get your code?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text(
                      '1. Contact your administrator\n'
                      '2. Request a registration code\n'
                      '3. Enter the code here to proceed',
                      style: TextStyle(color: Color.fromARGB(255, 6, 87, 167), fontSize: 14),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Verify Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyUserCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Verify Code',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              // Already have account?
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  child: const Text(
                    'Already have an account? Sign In',
                    style: TextStyle(color: Colors.blue, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
