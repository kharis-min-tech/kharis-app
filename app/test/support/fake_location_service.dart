import 'package:kharis_app/shared/providers/location_provider.dart';

/// A [LocationService] with no GPS: [granted] is the permission already
/// given, [allowOnRequest] what the prompt answers, [here] the one fix.
class FakeLocationService implements LocationService {
  FakeLocationService({
    this.granted = false,
    this.allowOnRequest = false,
    this.here,
  });

  bool granted;
  final bool allowOnRequest;
  final GeoPoint? here;

  /// How many times the member was asked.
  int requests = 0;

  @override
  Future<bool> isGranted() async => granted;

  @override
  Future<bool> requestPermission() async {
    requests++;
    granted = allowOnRequest;
    return granted;
  }

  @override
  Future<GeoPoint?> position() async => granted ? here : null;
}
