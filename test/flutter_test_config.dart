import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Nạp font của app cho mọi test, để chữ được dàn đúng như trên máy thật
/// thay vì font thử nghiệm mặc định (rộng hơn nhiều, dễ gây tràn bố cục).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  final loader = FontLoader('Montserrat');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final file = File('assets/fonts/Montserrat-$weight.ttf');
    loader.addFont(
      file.readAsBytes().then((bytes) => ByteData.view(bytes.buffer)),
    );
  }
  await loader.load();

  await testMain();
}
