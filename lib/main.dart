import 'package:material_ui/material_ui.dart';

import 'src/app.dart';
import 'src/dependency/injection.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies();
  runApp(const TachApp());
}
