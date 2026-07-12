import 'package:flutter/material.dart';
import '../theme/alpha_theme.dart';

class AccountNumberInput extends StatelessWidget {
  final TextEditingController controller;
  final FormFieldValidator<String>? validator;

  const AccountNumberInput({
    super.key,
    required this.controller,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      maxLength: 10,
      decoration: InputDecoration(
        labelText: 'Enter 10-digit account number',
        prefixIcon: const Icon(Icons.account_balance_outlined),
        counterText: '',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        suffixIcon: controller.text.length == 10
            ? const Icon(
                Icons.verified,
                color: AlphaTheme.successGreen,
              )
            : null,
      ),
      validator: validator,
      onChanged: (value) {
        // This triggers UI updates
      },
    );
  }
}
