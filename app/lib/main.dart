import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'core/di/injection.dart';
import 'core/navigation/navigation_cubit.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/bloc/auth_bloc.dart';

void main() async {
  // Always call this before any async work before runApp.
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Hold native splash until SplashPage removes it.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Wire every dependency. Order is handled inside injection.dart.
  await setupDependencies();

  runApp(const KhataDostApp());
}

class KhataDostApp extends StatelessWidget {
  const KhataDostApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Pull pre-built singletons out of GetIt into the widget tree.
        // BlocProvider.value because GetIt already owns the lifecycle —
        // BlocProvider should NOT close them when the widget disposes.
        BlocProvider.value(value: GetIt.I<NavigationCubit>()),
        BlocProvider.value(value: GetIt.I<AuthBloc>()),
      ],
      child: MaterialApp.router(
        title: 'KhataDost',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: GetIt.I<GoRouter>(),
      ),
    );
  }
}