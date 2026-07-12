# Alpha Bank App - Correct Import Reference
# Generated: 12/02/2025 20:01:26

## CORRECT IMPORT PATTERNS

### From screens directory (e.g., lib/screens/alpha_dashboard.dart):
import '../widgets/balance_card.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';

### From widgets directory (e.g., lib/widgets/balance_card.dart):
import '../screens/alpha_dashboard.dart';
import '../models/transaction_model.dart';
import 'package:flutter/material.dart';

### From providers directory (e.g., lib/providers/auth_provider.dart):
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import 'package:flutter/material.dart';

### From models directory:
// Usually no imports needed, or:
import 'package:flutter/material.dart'; // if using Color, Icons

### From main.dart:
import './screens/splash_screen.dart';
import './screens/login_screen.dart';
import './screens/registration_screen.dart';
import './screens/alpha_dashboard.dart';
import './theme/alpha_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

## COMMON MISTAKES FIXED:
❌ import '../screens/user_screens/login_screen.dart'
✅ import '../screens/login_screen.dart'

❌ import '../widgets/user_widgets/balance_card.dart'
✅ import '../widgets/balance_card.dart'

❌ Missing: import 'package:flutter/material.dart'
✅ Added to all files using Flutter widgets

## FLUTTER IMPORTS TO ADD:
Add this to files using:
- Widget, BuildContext, MaterialApp, Scaffold
- Color, Colors, Icons, IconData
- Text, Container, Column, Row, etc.

import 'package:flutter/material.dart';

## PROVIDER IMPORTS:
Add this to files using Provider:
import 'package:provider/provider.dart';
