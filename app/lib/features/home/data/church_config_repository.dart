import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kharis_app/shared/models/campus_config.dart';

/// Reads the church-wide defaults Content Studio keeps under `config/*`:
/// - `config/giving`: the account a campus without its own `giving` gives to;
/// - `config/home`: the Home layout a campus without its own `home` shows.
///
/// Both are public-read. A missing doc, an unusable shape and read errors all
/// map to null, so the app falls through to its built-in defaults instead of
/// an empty Giving tab or Home.
class ChurchConfigRepository {
  ChurchConfigRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<GivingDetails?> watchGiving() => _firestore
      .collection('config')
      .doc('giving')
      .snapshots()
      .map((doc) => GivingDetails.fromJson(doc.data()))
      .transform(_orDefault<GivingDetails?>(null));

  Stream<HomeLayout?> watchHomeLayout() => _firestore
      .collection('config')
      .doc('home')
      .snapshots()
      .map((doc) => HomeLayout.fromJson(doc.data()))
      .transform(_orDefault<HomeLayout?>(null));
}

/// Replaces a stream error (e.g. permission-denied) with [fallback].
StreamTransformer<T, T> _orDefault<T>(T fallback) =>
    StreamTransformer<T, T>.fromHandlers(
      handleError: (_, _, sink) => sink.add(fallback),
    );
