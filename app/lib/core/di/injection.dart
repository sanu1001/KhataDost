import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../navigation/navigation_cubit.dart';
import '../router/app_router.dart';
import '../storage/secure_storage.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/data/datasources/auth_datasource.dart';
import '../../features/auth/data/datasources/auth_mock_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';

/// The global GetIt service locator.
/// Import this anywhere you need a registered instance outside the widget tree.
/// Inside widgets always prefer context.read<T>() — GetIt is for wiring only.
final getIt = GetIt.instance;

/// Called once from main() before runApp().
/// Registers every dependency in the correct order — bottom of the graph first.
/// Returns a [Future] so async registrations (e.g. SharedPreferences) work too.
Future<void> setupDependencies() async {

  // ── 1. Primitives ──────────────────────────────────────────────────────────
  // FlutterSecureStorage has no dependencies — register it bare.
  getIt.registerSingleton<FlutterSecureStorage>(
    const FlutterSecureStorage(),
  );

  // ── 2. Core services ───────────────────────────────────────────────────────
  getIt.registerSingleton<SecureStorageService>(
    SecureStorageService(getIt<FlutterSecureStorage>()),
  );

  // ── 3. Data sources ────────────────────────────────────────────────────────
  // Registered as the ABSTRACT type [AuthDataSource].
  // Phase 4 swap: replace AuthMockDatasource() with AuthRemoteDataSource(...)
  // Add this:
  // getIt.registerSingleton<AuthDataSource>(
  //   AuthRemoteDataSource(DioClient(getIt<SecureStorageService>())),
  // );
  // — nothing else in this file or anywhere else changes.
  getIt.registerSingleton<AuthDataSource>(
    AuthMockDatasource(),
  );

  // ── 4. Repositories ────────────────────────────────────────────────────────
  // Registered as the ABSTRACT type [AuthRepository].
  // The BLoC never knows the concrete impl exists.
  getIt.registerSingleton<AuthRepository>(
    AuthRepositoryImpl(
      datasource: getIt<AuthDataSource>(),
      storage: getIt<SecureStorageService>(),
    ),
  );

  // ── 5. BLoC ────────────────────────────────────────────────────────────────
  getIt.registerSingleton<AuthBloc>(
    AuthBloc(repository: getIt<AuthRepository>()),
  );

  // ── 6. Router ──────────────────────────────────────────────────────────────
  // AppRouter is registered so it can be disposed later if needed.
  // GoRouter is also extracted as its own singleton so NavigationCubit
  // and MaterialApp.router both reference the same instance.
  getIt.registerSingleton<AppRouter>(
    AppRouter(authBloc: getIt<AuthBloc>()),
  );
  getIt.registerSingleton<GoRouter>(
    getIt<AppRouter>().router,
  );

  // ── 7. Navigation ──────────────────────────────────────────────────────────
  // Depends on GoRouter — must come after step 6.
  getIt.registerSingleton<NavigationCubit>(
    NavigationCubit(getIt<GoRouter>()),
  );
}