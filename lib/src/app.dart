import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import 'core/theme/app_theme.dart';
import 'dependency/injection.dart';
import 'domain/repositories/group_repository.dart';
import 'presentation/launch/launch_gate.dart';
import 'presentation/ledger/ledger_cubit.dart';

class TachApp extends StatelessWidget {
  const TachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LedgerCubit(getIt<GroupRepository>()),
      child: MaterialApp(
        title: 'Tach',
        debugShowCheckedModeBanner: false,
        theme: tachLightTheme,
        home: const LaunchGate(),
      ),
    );
  }
}
