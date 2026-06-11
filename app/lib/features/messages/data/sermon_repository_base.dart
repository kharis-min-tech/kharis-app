import 'package:kharis_app/shared/models/sermon.dart';

/// Contract shared by the RSS repository and the Firestore repository.
abstract class AbstractSermonRepository {
  /// Fetches the freshest sermon list available to this repository.
  Future<List<Sermon>> getSermons();

  /// Loads the guaranteed full catalogue (bundled asset; never empty).
  Future<List<Sermon>> loadCatalogue();
}
