import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';

class RemoteConfigService {
  final FirebaseRemoteConfig? remoteConfig;
  RemoteConfigService({this.remoteConfig});

  final defaults = <String, dynamic>{
    'remoteBuildNumber': 1,
    'force_update': false,
    'current_ios_version': '1.0.0',
    'current_android_version': '1.0.0',
    'ios_active': true,
    'android_active': true,
    'use_remote_config': true,
    'ios_deactivation_msg':
        "Dear Customer, Our services are unavailable at the moment. please contact support for more information.",
    'android_deactivation_msg':
        "Dear Customer, Our services are unavailable at the moment. please contact support for more information.",
    'android_update_mandatory': true,
    'ios_update_mandatory': true,
  };

  static RemoteConfigService? _instance;
  static Future<RemoteConfigService> getInstance() async {
    _instance ??= RemoteConfigService(
      remoteConfig: FirebaseRemoteConfig.instance,
    );
    return _instance!;
  }

  Future initialize() async {
    debugPrint("initing remote");
    await getInstance();
    try {
      await remoteConfig!.setDefaults(defaults);
      await _fetchAndActivate();
    } catch (e) {
      debugPrint("Remote Config fetch throttled: $e");
    }
  }

  Future _fetchAndActivate() async {
    await remoteConfig!.fetch();
    await remoteConfig!.activate();
  }
}
