import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../navigation/navigation_cubit.dart';
import '../network/dio_client.dart';
import '../router/app_router.dart';
import '../storage/secure_storage.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/bloc/auth_event.dart';
import '../../features/auth/data/datasources/auth_datasource.dart';
// import '../../features/auth/data/datasources/auth_mock_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';

import '../../features/dashboard/data/datasources/dashboard_datasource.dart';
// import '../../features/dashboard/data/datasources/dashboard_mock_datasource.dart';
import '../../features/dashboard/data/datasources/dashboard_remote_datasource.dart';
import '../../features/dashboard/data/repositories/dashboard_repository_impl.dart';
import '../../features/dashboard/domain/repositories/dashboard_repository.dart';
import '../../features/dashboard/presentation/bloc/dashboard_bloc.dart';

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

  // Single shared Dio + interceptor chain for every remote datasource.
  // Lifted here when the dashboard came online so we don't spawn one Dio
  // instance per feature.
  //
  // onUnauthorized fires when an AUTHENTICATED request comes back 401
  // (token expired / revoked). We dispatch LogoutRequested on AuthBloc:
  //   → AuthRepository.logout() → SecureStorage.clearToken()
  //   → AuthBloc emits unauthenticated
  //   → router refreshListenable fires → guard redirects to /welcome.
  //
  // The getIt<AuthBloc>() lookup is lazy — it only runs when 401 actually
  // fires, by which point AuthBloc has been registered below.
  getIt.registerSingleton<DioClient>(
    DioClient(
      getIt<SecureStorageService>(),
      onUnauthorized: () => getIt<AuthBloc>().add(const LogoutRequested()),
    ),
  );

  // ── 3. Data sources ────────────────────────────────────────────────────────
  // Each datasource is registered against its ABSTRACT type so repositories
  // (and BLoCs) never see the concrete impl. Mock registrations are kept in
  // commented form for tests + portfolio — flip the comments to roll back.
  getIt.registerSingleton<AuthDataSource>(
    AuthRemoteDataSource(getIt<DioClient>()),
  );
  // getIt.registerSingleton<AuthDataSource>(
  //   AuthMockDatasource(),
  // );

  getIt.registerSingleton<DashboardDataSource>(
    DashboardRemoteDataSource(getIt<DioClient>()),
  );
  // getIt.registerSingleton<DashboardDataSource>(
  //   DashboardMockDatasource(),
  // );

  // ── 4. Repositories ────────────────────────────────────────────────────────
  // Registered as the ABSTRACT type [AuthRepository].
  // The BLoC never knows the concrete impl exists.
  getIt.registerSingleton<AuthRepository>(
    AuthRepositoryImpl(
      datasource: getIt<AuthDataSource>(),
      storage: getIt<SecureStorageService>(),
    ),
  );
  getIt.registerSingleton<DashboardRepository>(
    DashboardRepositoryImpl(datasource: getIt<DashboardDataSource>()),
  );

  // ── 5. BLoC ────────────────────────────────────────────────────────────────
  getIt.registerSingleton<AuthBloc>(
    AuthBloc(repository: getIt<AuthRepository>()),
  );

  getIt.registerSingleton<DashboardBloc>(
    DashboardBloc(repository: getIt<DashboardRepository>()),
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
