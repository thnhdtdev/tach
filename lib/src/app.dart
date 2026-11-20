import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import 'core/theme/app_theme.dart';
import 'dependency/injection.dart';
import 'domain/repositories/budget_repository.dart';
import 'domain/repositories/group_repository.dart';
import 'presentation/jar/budget_cubit.dart';
import 'presentation/launch/launch_gate.dart';
import 'presentation/ledger/home_widget_sync.dart';
import 'presentation/ledger/ledger_cubit.dart';
import 'services/home_widget/home_widget_updater.dart';
import 'services/photo/photo_loader.dart';

class TachApp extends StatelessWidget {
  const TachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) {
            final cubit = LedgerCubit(getIt<GroupRepository>());
            HomeWidgetSync(
              cubit,
              getIt<HomeWidgetUpdater>(),
              getIt<PhotoLoader>(),
            );
            return cubit;
          },
        ),
        BlocProvider(create: (_) => BudgetCubit(getIt<BudgetRepository>())),
      ],
      child: MaterialApp(
        title: 'Tach',
        debugShowCheckedModeBanner: false,
        theme: tachTheme,
        // Nền app tối ở mọi màn, nên thanh trạng thái luôn dùng chữ sáng.
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: child!,
        ),
        home: const LaunchGate(),
      ),
    );
  }
}
