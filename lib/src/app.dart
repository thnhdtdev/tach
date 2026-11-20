import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import 'core/theme/app_theme.dart';
import 'dependency/injection.dart';
import 'domain/repositories/group_repository.dart';
import 'presentation/launch/launch_gate.dart';
import 'presentation/ledger/home_widget_sync.dart';
import 'presentation/ledger/ledger_cubit.dart';
import 'services/home_widget/home_widget_updater.dart';
import 'services/photo/photo_loader.dart';

class TachApp extends StatelessWidget {
  const TachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = LedgerCubit(getIt<GroupRepository>());
        HomeWidgetSync(cubit, getIt<HomeWidgetUpdater>(), getIt<PhotoLoader>());
        return cubit;
      },
      child: MaterialApp(
        title: 'Tach',
        debugShowCheckedModeBanner: false,
        theme: tachLightTheme,
        home: const LaunchGate(),
      ),
    );
  }
}
