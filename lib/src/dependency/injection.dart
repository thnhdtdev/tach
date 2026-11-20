import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/auth_config.dart';
import '../datasource/sample/sample_group_repository.dart';
import '../datasource/supabase/supabase_group_repository.dart';
import '../domain/repositories/group_repository.dart';
import '../services/auth/auth_service.dart';
import '../services/auth/identity_provider.dart';
import '../services/avatar/avatar_picker.dart';
import '../services/camera/capture_camera.dart';
import '../services/home_widget/home_widget_updater.dart';
import '../services/photo/photo_loader.dart';
import '../services/photo/photo_sharer.dart';
import '../services/preferences/app_preferences.dart';

final getIt = GetIt.instance;

void configureDependencies({SupabaseClient? supabase}) {
  getIt
    ..registerLazySingleton<AppPreferences>(AppPreferences.new)
    ..registerLazySingleton<AvatarPicker>(ImagePickerAvatarPicker.new)
    ..registerLazySingleton<PhotoSharer>(SystemPhotoSharer.new)
    // Widget mới chỉ có trên iOS.
    ..registerLazySingleton<HomeWidgetUpdater>(
      () => defaultTargetPlatform == TargetPlatform.iOS
          ? SystemHomeWidgetUpdater()
          : NoHomeWidgetUpdater(),
    )
    ..registerFactory<CaptureCamera>(PluginCaptureCamera.new);

  if (supabase == null) {
    getIt
      ..registerLazySingleton<AuthService>(DemoAuthService.new)
      ..registerLazySingleton<PhotoLoader>(NoPhotoLoader.new)
      ..registerLazySingleton<GroupRepository>(SampleGroupRepository.new);
    return;
  }

  getIt
    ..registerLazySingleton<AuthService>(
      () => SupabaseAuthService(
        supabase,
        providers: [
          // Đăng nhập gốc mới cấu hình cho iOS.
          if (defaultTargetPlatform == TargetPlatform.iOS) ...[
            if (AuthConfig.appleEnabled) AppleIdentity(),
            if (AuthConfig.googleEnabled)
              GoogleIdentity(
                iosClientId: AuthConfig.googleIosClientId,
                webClientId: AuthConfig.googleWebClientId,
              ),
          ],
        ],
      ),
    )
    ..registerLazySingleton<PhotoLoader>(() => SupabasePhotoLoader(supabase))
    ..registerLazySingleton<GroupRepository>(
      () => SupabaseGroupRepository(supabase, getIt<PhotoLoader>()),
    );
}
