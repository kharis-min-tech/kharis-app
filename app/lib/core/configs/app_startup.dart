import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:kharis_app/core/services/firebase_service.dart';
import 'package:kharis_app/shared/models/remote_config.dart';
import 'package:kharis_app/shared/remote_config/remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';

// This is our global ServiceLocator
GetIt getIt = GetIt.instance;
RemoteConfigModel? _remoteConfig;

class AppStartUp {
  Future<void> setUp() async {
    getIt.allowReassignment = true;
    await registerServices(getIt);
    if (kUseFirebase) {
      await FirebaseService.init();
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    }
    if (kDebugMode) {
      await setRemoteConfig();
    }
  }

  Future<void> registerServices(GetIt ioc) async {}

  Future<void> setRemoteConfig() async {
    RemoteConfigService? remoteConfigService =
        await RemoteConfigService.getInstance();
    await remoteConfigService.initialize();
    remoteConfigService.remoteConfig?.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 12),
      ),
    );

    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String localBuildNumber = packageInfo.buildNumber;
    _remoteConfig = RemoteConfigModel(
      localBuildNumber: int.tryParse(localBuildNumber),
      forceUpdate: remoteConfigService.remoteConfig?.getBool('force_update'),
      remoteBuildNumber: remoteConfigService.remoteConfig?.getInt(
        'remoteBuildNumber',
      ),
    );

    getIt.registerSingleton<RemoteConfigModel>(_remoteConfig!);
  }
}
