import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:dio/dio.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/calendar/data/event_repository.dart';

/// The getEvents API is unreachable, so the Firestore path is what is tested.
class _OfflineAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'offline',
    );
  }

  @override
  void close({bool force = false}) {}
}

// Plain `test`s: Firestore snapshot streams do not deliver under flutter_test's
// FakeAsync zone.
void main() {
  late FakeFirebaseFirestore firestore;
  late EventRepository repo;
  final soon = Timestamp.fromDate(DateTime.now().add(const Duration(days: 3)));

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    repo = EventRepository(
      firestore: firestore,
      dio: Dio()..httpClientAdapter = _OfflineAdapter(),
    );
    final events = firestore.collection('events');
    await events.doc('web_1').set({
      'title': 'Website service',
      'source': 'website',
      'startTime': soon,
    });
    await events.doc('own').set({'title': 'Own event', 'startTime': soon});
  });

  test('deleting a website event leaves a hidden tombstone the sync keeps; '
      'other events are really deleted', () async {
    await repo.deleteEvent('web_1');
    await repo.deleteEvent('own');

    final web = await firestore.collection('events').doc('web_1').get();
    expect(web.exists, isTrue, reason: 'a missing web_ doc is re-imported');
    expect(web.data()!['hidden'], isTrue);
    expect(
      (await firestore.collection('events').doc('own').get()).exists,
      isFalse,
    );
  });

  test('hidden events are dropped by every Firestore read', () async {
    await firestore.collection('events').doc('web_1').update({'hidden': true});

    final upcoming = await repo.watchUpcomingEvents().first;
    expect(upcoming.map((e) => e.id), ['own']);
    expect(await repo.getEventById('web_1'), isNull);
    expect(await repo.getEventById('own'), isNotNull);
    expect((await repo.getEventsByIds(['web_1', 'own'])).map((e) => e.id), [
      'own',
    ]);
  });
}
