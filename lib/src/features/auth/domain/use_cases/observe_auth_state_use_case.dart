import 'package:kortex/src/features/auth/domain/entities/auth_status.dart';
import 'package:kortex/src/features/auth/domain/repositories/auth_repository.dart';

class ObserveAuthStateUseCase {
  const ObserveAuthStateUseCase(this._repository);

  final AuthRepository _repository;

  Stream<AuthSessionStatus> call() {
    return _repository.observeAuthState();
  }
}
