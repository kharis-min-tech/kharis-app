import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../features/onboarding/data/branch_repository.dart';

/// A point on the globe, in degrees.
@immutable
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

/// The device's location, behind an interface so tests never touch GPS.
///
/// Kharis only ever asks for approximate location, and only when the member
/// taps "Use my location".
abstract class LocationService {
  /// Whether location is already allowed. Never prompts.
  Future<bool> isGranted();

  /// Asks for location when it has not been decided yet. True when allowed.
  Future<bool> requestPermission();

  /// One approximate fix, or null when none can be had. Never prompts.
  Future<GeoPoint?> position();
}

/// [LocationService] on the platform location APIs.
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  static bool _allowed(LocationPermission p) =>
      p == LocationPermission.whileInUse || p == LocationPermission.always;

  @override
  Future<bool> isGranted() async {
    try {
      return _allowed(await Geolocator.checkPermission());
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      return _allowed(await Geolocator.requestPermission());
    } catch (_) {
      return false;
    }
  }

  @override
  Future<GeoPoint?> position() async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return GeoPoint(p.latitude, p.longitude);
    } catch (_) {
      // Location services off, or no fix in time.
      return null;
    }
  }
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => const GeolocatorLocationService(),
);

/// Great-circle (haversine) distance between [a] and [b], in metres.
double distanceMeters(GeoPoint a, GeoPoint b) {
  const earthRadius = 6371008.8;
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(b.latitude - a.latitude);
  final dLng = rad(b.longitude - a.longitude);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.latitude)) *
          math.cos(rad(b.latitude)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadius * math.asin(math.min(1, math.sqrt(h)));
}

/// A branch and how far its nearest venue is.
@immutable
class NearestBranch {
  const NearestBranch(this.branch, this.meters);

  final Branch branch;
  final double meters;

  /// "2.3 mi" under ten miles, whole miles beyond.
  String get distanceLabel {
    final miles = meters / 1609.344;
    return miles < 10
        ? '${miles.toStringAsFixed(1)} mi'
        : '${miles.round()} mi';
  }

  /// "Nearest: Bristol · 2.3 mi".
  String get label => 'Nearest: ${branch.name} · $distanceLabel';
}

/// The branch whose closest venue is nearest [here]. Branches without a
/// venue carrying coordinates are skipped; null when none has one.
NearestBranch? nearestBranch(Iterable<Branch> branches, GeoPoint here) {
  NearestBranch? best;
  for (final b in branches) {
    for (final v in b.venues) {
      final lat = v.latitude;
      final lng = v.longitude;
      if (lat == null || lng == null) continue;
      final d = distanceMeters(here, GeoPoint(lat, lng));
      if (best == null || d < best.meters) best = NearestBranch(b, d);
    }
  }
  return best;
}

/// The device's position when location is already allowed, else null.
/// Never prompts: this feeds Home for members who have not chosen a branch.
final grantedPositionProvider = FutureProvider<GeoPoint?>((ref) async {
  final location = ref.watch(locationServiceProvider);
  if (!await location.isGranted()) return null;
  return location.position();
});
