import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import '../../../../core/navigation/navigation_cubit.dart';
import '../../bloc/auth_bloc.dart';
import '../../bloc/auth_event.dart';
import '../../bloc/auth_state.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    context.read<AuthBloc>().add(const AppStarted());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state){
        // await Future.delayed(const Duration(seconds: 4));
        if (state.status == AuthStatus.authenticated) {
          FlutterNativeSplash.remove();
          context.read<NavigationCubit>().goToDashboard();
        } else if (state.status == AuthStatus.unauthenticated) {
          FlutterNativeSplash.remove();
          context.read<NavigationCubit>().goToWelcome();
        }
      },
      child: const Scaffold(
        backgroundColor: Colors.white,
        body: SizedBox.expand(),
      ),
    );
  }
}