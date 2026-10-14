// Platform-channel stand-ins for the journeys.
//
// url_launcher, share_plus and add_2_calendar are answered here instead of by
// the OS: the journeys assert what the app asked for (URL, launch mode,
// calendar event, share text) without leaving the app, adding calendar
// entries or opening the OS share sheet. The share sheet in particular cannot
// be closed on a headless iOS simulator (simctl has no input channel), which
// used to leave it over the app for the rest of the run.
//
// firebase_messaging is spied on, not answered: calls reach the real plugin.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class NativeCall {
  NativeCall(this.channel, this.method, this.args) : at = DateTime.now();

  final String channel;
  final String method;
  final Object? args;
  final DateTime at;

  @override
  String toString() => '$method($args)';
}

/// A url_launcher request as the platform received it.
class Launch {
  Launch(this.url, {required this.external});

  final String url;

  /// True for LaunchMode.externalApplication (the plugin's `launchUrl`
  /// host call without the non-browser flag); false for in-app browsers.
  final bool external;

  @override
  String toString() => '${external ? 'external' : 'in-app'} $url';
}

final List<Launch> launches = [];
final List<Map<Object?, Object?>> calendarAdds = [];
final List<String> shares = [];
final List<NativeCall> messagingCalls = [];

void resetChannelRecords() {
  launches.clear();
  calendarAdds.clear();
  shares.clear();
  messagingCalls.clear();
}

const _iosLaunch =
    'dev.flutter.pigeon.url_launcher_ios.UrlLauncherApi.launchUrl';
const _iosInApp =
    'dev.flutter.pigeon.url_launcher_ios.UrlLauncherApi.openUrlInSafariViewController';
const _androidLaunch =
    'dev.flutter.pigeon.url_launcher_android.UrlLauncherApi.launchUrl';
const _androidInApp =
    'dev.flutter.pigeon.url_launcher_android.UrlLauncherApi.openUrlInApp';
const _messagingChannel = 'plugins.flutter.io/firebase_messaging';

/// Pigeon enum value as url_launcher_ios encodes it (custom type byte, then
/// the index).
class _PigeonEnum {
  const _PigeonEnum(this.type, this.index);
  final int type;
  final int index;
}

class _PigeonReplyCodec extends StandardMessageCodec {
  const _PigeonReplyCodec();

  @override
  void writeValue(WriteBuffer buffer, Object? value) {
    if (value is _PigeonEnum) {
      buffer.putUint8(value.type);
      writeValue(buffer, value.index);
    } else {
      super.writeValue(buffer, value);
    }
  }
}

String? _firstString(Object? decoded) {
  if (decoded is List) {
    for (final v in decoded) {
      if (v is String) return v;
    }
  }
  return null;
}

/// Decodes the leading URL of a pigeon call; custom argument types (Android
/// in-app options) make the standard codec throw past the URL, so the bytes
/// are read up to the first value only.
String? _pigeonUrl(ByteData? message) {
  if (message == null) return null;
  try {
    return _firstString(const StandardMessageCodec().decodeMessage(message));
  } catch (_) {
    final buffer = ReadBuffer(message);
    // List header: type byte + size, then the URL string.
    buffer.getUint8();
    const codec = StandardMessageCodec();
    codec.readSize(buffer);
    final v = codec.readValue(buffer);
    return v is String ? v : null;
  }
}

void installChannelFakes() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  // url_launcher (iOS): LaunchResult.success = custom type 129, index 0.
  messenger.setMockMessageHandler(_iosLaunch, (message) async {
    final decoded = const StandardMessageCodec().decodeMessage(message);
    final nonBrowserOnly = decoded is List && decoded.length > 1
        ? decoded[1] == true
        : false;
    launches.add(
      Launch(_firstString(decoded) ?? '?', external: !nonBrowserOnly),
    );
    return const _PigeonReplyCodec().encodeMessage([const _PigeonEnum(129, 0)]);
  });
  // InAppLoadResult.success = custom type 130, index 0.
  messenger.setMockMessageHandler(_iosInApp, (message) async {
    launches.add(Launch(_pigeonUrl(message) ?? '?', external: false));
    return const _PigeonReplyCodec().encodeMessage([const _PigeonEnum(130, 0)]);
  });
  messenger.setMockMessageHandler(_androidLaunch, (message) async {
    final decoded = const StandardMessageCodec().decodeMessage(message);
    final nonBrowserOnly = decoded is List && decoded.length > 2
        ? decoded[2] == true
        : false;
    launches.add(
      Launch(_firstString(decoded) ?? '?', external: !nonBrowserOnly),
    );
    return const StandardMessageCodec().encodeMessage([true]);
  });
  messenger.setMockMessageHandler(_androidInApp, (message) async {
    launches.add(Launch(_pigeonUrl(message) ?? '?', external: false));
    return const StandardMessageCodec().encodeMessage([true]);
  });

  messenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/share'),
    (call) async {
      final args = call.arguments;
      shares.add(args is Map ? '${args['text'] ?? args}' : '$args');
      // '' = the member dismissed the sheet.
      return '';
    },
  );

  messenger.setMockMethodCallHandler(
    const MethodChannel('add_2_calendar_new'),
    (call) async {
      if (call.method == 'add2Cal') {
        calendarAdds.add(Map<Object?, Object?>.from(call.arguments as Map));
      }
      return true;
    },
  );

  // Pass-through spy: the real plugin answers.
  messenger.setMockMessageHandler(_messagingChannel, (message) async {
    try {
      final call = const StandardMethodCodec().decodeMethodCall(message);
      messagingCalls.add(NativeCall(_messagingChannel, call.method, null));
    } catch (_) {}
    return messenger.delegate.send(_messagingChannel, message) ??
        Future<ByteData?>.value();
  });
}

Iterable<NativeCall> permissionRequests() =>
    messagingCalls.where((c) => c.method.contains('requestPermission'));
