import 'package:flutter/material.dart';
import '../theme/alpha_theme.dart';

class PinInputField extends StatefulWidget {
  final TextEditingController controller;
  final int length;
  final ValueChanged<String>? onChanged;

  const PinInputField({
    super.key,
    required this.controller,
    this.length = 4,
    this.onChanged,
    required bool obscureText,
  });

  @override
  State<PinInputField> createState() => _PinInputFieldState();
}

class _PinInputFieldState extends State<PinInputField> {
  late List<FocusNode> _focusNodes;
  late List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _focusNodes = List.generate(widget.length, (index) => FocusNode());
    _controllers =
        List.generate(widget.length, (index) => TextEditingController());

    // Initialize main controller
    widget.controller.text = '';
  }

  @override
  void dispose() {
    for (var node in _focusNodes) {
      node.dispose();
    }
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onChanged(int index, String value) {
    if (value.isNotEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }

    // Update the combined PIN
    String pin = '';
    for (var controller in _controllers) {
      pin += controller.text;
    }
    widget.controller.text = pin;

    widget.onChanged?.call(pin);
  }

  void _onBackspace(int index, String value) {
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(
        widget.length,
        (index) => SizedBox(
          width: 60,
          child: TextField(
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            obscureText: true,
            obscuringCharacter: '●',
            style: AlphaTheme.headingLarge.copyWith(fontSize: 24),
            decoration: InputDecoration(
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: AlphaTheme.darkGray.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: AlphaTheme.darkGray.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AlphaTheme.primaryBlue, width: 2),
              ),
            ),
            onChanged: (value) {
              _onChanged(index, value);
            },
            onSubmitted: (value) {
              _onChanged(index, value);
            },
          ),
        ),
      ),
    );
  }
}
