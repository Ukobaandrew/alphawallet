import 'package:flutter/material.dart';
import '../theme/alpha_theme.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const PasswordStrengthIndicator({
    super.key,
    required this.password,
  });

  int _calculateStrength() {
    if (password.isEmpty) return 0;

    int strength = 0;
    if (password.length >= 8) strength++;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength++;
    if (RegExp(r'[a-z]').hasMatch(password)) strength++;
    if (RegExp(r'[0-9]').hasMatch(password)) strength++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength++;

    return strength;
  }

  String _getStrengthText(int strength) {
    if (strength <= 1) return 'Very Weak';
    if (strength == 2) return 'Weak';
    if (strength == 3) return 'Good';
    if (strength == 4) return 'Strong';
    return 'Very Strong';
  }

  Color _getStrengthColor(int strength) {
    if (strength <= 1) return AlphaTheme.errorRed;
    if (strength == 2) return AlphaTheme.warningYellow;
    if (strength == 3) return Colors.blue;
    if (strength == 4) return AlphaTheme.successGreen;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final strength = _calculateStrength();
    final width = MediaQuery.of(context).size.width - 40;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Password Strength',
              style: AlphaTheme.bodySmall,
            ),
            Text(
              _getStrengthText(strength),
              style: AlphaTheme.bodySmall.copyWith(
                color: _getStrengthColor(strength),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 6,
          width: width,
          decoration: BoxDecoration(
            color: AlphaTheme.lightGray,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Row(
            children: List.generate(5, (index) {
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index < 4 ? 2 : 0),
                  decoration: BoxDecoration(
                    color: index < strength
                        ? _getStrengthColor(strength)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
