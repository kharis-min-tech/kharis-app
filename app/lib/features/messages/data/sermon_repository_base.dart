import 'package:kharis_app/shared/models/sermon.dart';

/// Shared contract for both the RSS-based and Firestore-based sermon sources.
abstract class AbstractSermonRepository {
  Future<List<Sermon>> getSermons();
  List<Sermon> getMockSermons();
}
