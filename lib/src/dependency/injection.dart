import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../datasource/sample/sample_group_repository.dart';
import '../datasource/supabase/supabase_group_repository.dart';
import '../domain/repositories/group_repository.dart';
import '../services/auth/auth_service.dart';
import '../services/avatar/avatar_picker.dart';
import '../services/camera/capture_camera.dart';
import '../services/photo/photo_loader.dart';
import '../services/preferences/app_preferences.dart';

final getIt = GetIt.instance;

/// Đăng ký các phụ thuộc dùng chung. Gọi một lần trước `runApp`.
///
/// Có [supabase] thì đăng nhập và dữ liệu đi qua Supabase; không có thì app
/// chạy bằng dữ liệu mẫu trong bộ nhớ (dùng cho test và khi chưa cấu hình).
void configureDependencies({SupabaseClient? supabase}) {
  getIt
    ..registerLazySingleton<AppPreferences>(AppPreferences.new)
    ..registerLazySingleton<AvatarPicker>(ImagePickerAvatarPicker.new)
    // Mỗi màn chụp giữ một camera riêng và tự nhả khi rời màn.
    ..registerFactory<CaptureCamera>(PluginCaptureCamera.new);

  if (supabase == null) {
    getIt
      ..registerLazySingleton<AuthService>(DemoAuthService.new)
      ..registerLazySingleton<PhotoLoader>(NoPhotoLoader.new)
      ..registerLazySingleton<GroupRepository>(SampleGroupRepository.new);
    return;
  }

  getIt
    ..registerLazySingleton<AuthService>(() => SupabaseAuthService(supabase))
    ..registerLazySingleton<PhotoLoader>(() => SupabasePhotoLoader(supabase))
    ..registerLazySingleton<GroupRepository>(
      () => SupabaseGroupRepository(supabase, getIt<PhotoLoader>()),
    );
}
