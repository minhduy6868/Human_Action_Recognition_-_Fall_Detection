import 'package:flutter/material.dart';

import 'get_it_dependencies.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initGetItDependencies();

  runApp(const App());
}
