import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kharis_app/core/services/notification_service.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';
import 'package:kharis_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:kharis_app/shared/models/campus_config.dart';
import 'package:kharis_app/shared/models/user.dart';
import 'package:kharis_app/shared/providers/admin_provider.dart';
import 'package:kharis_app/shared/providers/auth_provider.dart';
import 'package:kharis_app/shared/providers/branch_provider.dart';
import 'package:kharis_app/shared/providers/campus_config_provider.dart';
import 'package:kharis_app/shared/providers/location_provider.dart';
import 'package:kharis_app/shared/providers/notification_provider.dart';
import 'package:kharis_app/shared/providers/onboarding_provider.dart';
import 'package:kharis_app/shared/widgets/branch_picker_sheet.dart';

import 'support/fake_location_service.dart';

/// Every member has a branch: "All branches" is no longer a member's
/// choice, "Use my location" picks the nearest branch, and Home follows the
/// chosen branch, else the nearest (location already allowed), else London.

/// Topic switches go nowhere.
class _QuietNotificationService extends NotificationService {
  @override
  Future<void> switchBranchTopic({String? from, String? to}) async {}
}

Branch _branch(String name, double lat, double lng) => Branch(
  id: name.toLowerCase(),
  name: name,
  subtitle: '$name branch',
  gradientStart: Colors.black,
  gradientEnd: Colors.black,
  venues: [CampusVenue(id: '$name-hall', latitude: lat, longitude: lng)],
);

final _london = _branch('London', 51.5007, -0.1246);
final _bristol = _branch('Bristol', 51.4545, -2.5879);

/// A venue-less branch: never "nearest".
const _online = Branch(
  id: 'online',
  name: 'Online',
  subtitle: '',
  gradientStart: Colors.black,
  gradientEnd: Colors.black,
);

/// About a mile from the Bristol venue.
const _nearBristol = GeoPoint(51.47, -2.6);

/// Near the London venue.
const _nearLondon = GeoPoint(51.51, -0.13);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('nearestBranch', () {
    test('picks the branch whose venue is closest, skipping venue-less '
        'branches', () {
      final hit = nearestBranch([_online, _london, _bristol], _nearBristol)!;
      expect(hit.branch.name, 'Bristol');
      expect(hit.label, matches(RegExp(r'^Nearest: Bristol · \d\.\d mi$')));
      expect(nearestBranch([_online], _nearBristol), isNull);
    });

    test('measures great-circle distance', () {
      // London to Bristol is about 171 km (106 mi) as the crow flies.
      final d = distanceMeters(
        const GeoPoint(51.5007, -0.1246),
        const GeoPoint(51.4545, -2.5879),
      );
      expect(d, closeTo(171000, 3000));
      expect(NearestBranch(_bristol, d).distanceLabel, '106 mi');
    });
  });

  group('homeBranchProvider', () {
    Future<(ProviderContainer, FakeLocationService)> resolve({
      required String? chosen,
      required FakeLocationService location,
    }) async {
      final c = ProviderContainer(
        overrides: [
          currentBranchProvider.overrideWith((ref) => Stream.value(chosen)),
          branchesProvider.overrideWith(
            (ref) => Stream.value([_london, _bristol]),
          ),
          locationServiceProvider.overrideWithValue(location),
        ],
      );
      addTearDown(c.dispose);
      c.listen(homeCampusProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return (c, location);
    }

    test('is the chosen branch', () async {
      final (c, _) = await resolve(
        chosen: 'Bristol',
        location: FakeLocationService(granted: true, here: _nearLondon),
      );
      expect(c.read(homeBranchProvider).value, 'Bristol');
      expect(c.read(homeCampusProvider)?.name, 'Bristol');
    });

    test('with none chosen, is the nearest branch when location is already '
        'allowed, without asking', () async {
      final (c, location) = await resolve(
        chosen: null,
        location: FakeLocationService(granted: true, here: _nearBristol),
      );
      expect(c.read(homeBranchProvider).value, 'Bristol');
      expect(c.read(homeCampusProvider)?.name, 'Bristol');
      expect(location.requests, 0);
    });

    test(
      'with none chosen and no location, is London, without asking',
      () async {
        final (c, location) = await resolve(
          chosen: null,
          location: FakeLocationService(
            allowOnRequest: true,
            here: _nearBristol,
          ),
        );
        expect(c.read(homeBranchProvider).value, 'London');
        expect(c.read(homeCampusProvider)?.name, 'London');
        expect(location.requests, 0);
      },
    );
  });

  group('branch picker', () {
    late SharedPreferences prefs;

    Future<ProviderContainer> pumpPicker(
      WidgetTester tester, {
      required FakeLocationService location,
      bool allowAll = false,
    }) async {
      SharedPreferences.setMockInitialValues({'onboarding_completed': true});
      prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentUserProvider.overrideWith((ref) => Stream.value(null)),
          notificationServiceProvider.overrideWithValue(
            _QuietNotificationService(),
          ),
          branchesProvider.overrideWith(
            (ref) => Stream.value([_london, _bristol]),
          ),
          locationServiceProvider.overrideWithValue(location),
        ],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () => allowAll
                      ? showBranchPicker(context, current: null, allowAll: true)
                      : pickActiveBranch(context, ref),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return c;
    }

    final useLocation = find.byKey(const ValueKey('branch-use-location'));
    final status = find.byKey(const ValueKey('branch-location-status'));

    testWidgets('offers "Use my location" and every branch, never "All '
        'branches"', (tester) async {
      final location = FakeLocationService();
      await pumpPicker(tester, location: location);

      expect(find.byType(BranchPickerSheet), findsOneWidget);
      expect(useLocation, findsOneWidget);
      expect(
        find.byKey(const ValueKey('branch-choice-London')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('branch-choice-Bristol')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('branch-choice-all')), findsNothing);
      expect(find.text('All branches'), findsNothing);
      expect(location.requests, 0, reason: 'location is asked only on tap');
    });

    testWidgets('the Events tab browse filter still offers "All branches"', (
      tester,
    ) async {
      await pumpPicker(tester, location: FakeLocationService(), allowAll: true);
      expect(find.byKey(const ValueKey('branch-choice-all')), findsOneWidget);
      expect(useLocation, findsOneWidget);
    });

    testWidgets('"Use my location" asks, shows the nearest branch and its '
        'distance, then chooses it', (tester) async {
      final location = FakeLocationService(
        allowOnRequest: true,
        here: _nearBristol,
      );
      final c = await pumpPicker(tester, location: location);

      await tester.tap(useLocation);
      await tester.pump();
      await tester.pump();
      expect(location.requests, 1);
      final shown = tester.widget<Text>(status).data!;
      expect(shown, matches(RegExp(r'^Nearest: Bristol · \d\.\d mi$')));

      await tester.pump(kNearestBranchHold);
      await tester.pumpAndSettle();
      expect(find.byType(BranchPickerSheet), findsNothing);
      expect(prefs.getString('onboarding_branch'), 'Bristol');
      expect(await c.read(currentBranchProvider.future), 'Bristol');
      expect(find.text('Your branch is now Bristol.'), findsOneWidget);
    });

    testWidgets('denied location says so and the list stays usable', (
      tester,
    ) async {
      final location = FakeLocationService(here: _nearBristol);
      await pumpPicker(tester, location: location);

      await tester.tap(useLocation);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(status).data,
        'Location is off for Kharis. Choose your branch below.',
      );
      expect(find.byType(BranchPickerSheet), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('branch-choice-London')));
      await tester.pumpAndSettle();
      expect(prefs.getString('onboarding_branch'), 'London');
    });

    testWidgets('no position says so and chooses nothing', (tester) async {
      await pumpPicker(tester, location: FakeLocationService(granted: true));

      await tester.tap(useLocation);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(status).data,
        'We couldn\u2019t find your location. Choose below.',
      );
      expect(find.byType(BranchPickerSheet), findsOneWidget);
      expect(prefs.getString('onboarding_branch'), isNull);
    });
  });

  testWidgets('More reads "Choose your branch" while none is chosen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final member = User(
      id: 'm-1',
      email: 'member@kharis.org',
      displayName: 'Ada Member',
      role: 'member',
      createdAt: DateTime(2026),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
          currentUserProvider.overrideWith((ref) => Stream.value(member)),
          currentBranchProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Switch branch'), findsOneWidget);
    expect(find.text('Choose your branch'), findsOneWidget);
    expect(find.text('All branches'), findsNothing);
  });
}
