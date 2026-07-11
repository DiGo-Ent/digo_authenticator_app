import 'package:get_it/get_it.dart';
import '../security/secure_storage_service.dart';
import '../security/encryption_service.dart';
import '../security/database_service.dart';
import '../../features/authenticator/domain/repositories/authenticator_repository.dart';
import '../../features/authenticator/data/repositories/authenticator_repository_impl.dart';

final getIt = GetIt.instance;

Future<void> setupDependencyInjection() async {
  final secureStorage = SecureStorageService();
  getIt.registerSingleton<SecureStorageService>(secureStorage);

  final masterKey = await secureStorage.getOrCreateMasterKey();
  final encryptionService = EncryptionService(masterKey);
  getIt.registerSingleton<EncryptionService>(encryptionService);

  final databaseService = DatabaseService();
  getIt.registerSingleton<DatabaseService>(databaseService);

  final authenticatorRepository = AuthenticatorRepositoryImpl(databaseService, encryptionService);
  getIt.registerSingleton<AuthenticatorRepository>(authenticatorRepository);
}
