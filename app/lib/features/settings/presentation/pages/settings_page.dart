import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/navigation/navigation_cubit.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../auth/bloc/auth_event.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';
import '../widgets/about_section.dart';
import '../widgets/profile_card.dart';
import '../widgets/settings_tile.dart';

/// The Settings page (top-level /settings route, outside the shell).
/// Provides its own SettingsBloc (GetIt singleton) — the router's route stays
/// `const SettingsPage()` untouched. AuthBloc + NavigationCubit are pulled
/// from the root providers (main.dart) via context.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SettingsBloc>.value(
      value: GetIt.I<SettingsBloc>(),
      child: const _SettingsView(),
    );
  }
}

class _SettingsView extends StatefulWidget {
  const _SettingsView();

  @override
  State<_SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<_SettingsView> {
  @override
  void initState() {
    super.initState();
    context.read<SettingsBloc>().add(const LoadProfile());
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out of KhataDost?'),
        content: const Text(
          'You will need to log in again to access your shop.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    // Read-only reuse of the frozen AuthBloc's public event:
    // clears the token → emits unauthenticated.
    context.read<AuthBloc>().add(const LogoutRequested());
    // /settings is a top-level route (not /home/*), so the auth redirect
    // guard won't bounce us — navigate to welcome explicitly.
    context.read<NavigationCubit>().goToWelcomeOnLogout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Profile ─────────────────────────────────────────────────────
          BlocBuilder<SettingsBloc, SettingsState>(
            builder: (context, state) {
              switch (state.status) {
                case SettingsStatus.loaded:
                  return ProfileCard(profile: state.profile!);
                case SettingsStatus.failure:
                  return _ProfileError(
                    message: state.errorMessage ?? 'Could not load profile',
                    onRetry: () =>
                        context.read<SettingsBloc>().add(const LoadProfile()),
                  );
                default:
                  return const _ProfileLoading();
              }
            },
          ),

          // ── Account ─────────────────────────────────────────────────────
          const _SectionHeader('Account'),
          SettingsTile(
            icon: Icons.lock_outline,
            title: 'Change password',
            onTap: () => context.read<NavigationCubit>().pushChangePassword(),
          ),
          SettingsTile(
            icon: Icons.logout,
            title: 'Log out',
            destructive: true,
            onTap: _confirmLogout,
          ),

          // ── Preferences (Coming soon stubs) ───────────────────────────────
          const _SectionHeader('Preferences'),
          const SettingsTile(
            icon: Icons.language,
            title: 'Language',
            subtitle: 'Coming soon',
            enabled: false,
          ),
          const SettingsTile(
            icon: Icons.dark_mode_outlined,
            title: 'Theme',
            subtitle: 'Coming soon',
            enabled: false,
          ),

          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.divider),
          const AboutSection(),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _ProfileLoading extends StatelessWidget {
  const _ProfileLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.errorSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.error),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
