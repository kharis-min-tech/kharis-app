import 'package:get_it/get_it.dart';
import 'package:kharis_app/core/services/firebase_service.dart';

// This is our global ServiceLocator
GetIt getIt = GetIt.instance;

class AppStartUp {
  Future<void> setUp() async {
    getIt.allowReassignment = true;
    await registerServices(getIt);
    if (kUseFirebase) {
      await FirebaseService.init();
    }
  }

  Future<void> registerServices(GetIt ioc) async {}
}
