import 'package:get_it/get_it.dart';

import '../datasource/sample/sample_group_repository.dart';
import '../domain/repositories/group_repository.dart';
import '../services/preferences/app_preferences.dart';

final getIt = GetIt.instance;

/// Đăng ký các phụ thuộc dùng chung. Gọi một lần trước `runApp`.
void configureDependencies() {
  getIt
    ..registerLazySingleton<AppPreferences>(AppPreferences.new)
    // Tạm dùng dữ liệu mẫu cho tới khi có bản Supabase.
    ..registerLazySingleton<GroupRepository>(SampleGroupRepository.new);
}
