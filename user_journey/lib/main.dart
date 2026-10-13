import 'package:flutter/material.dart';

import 'app.dart';
import 'di.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies();
  runApp(const HealthTickApp());
}
