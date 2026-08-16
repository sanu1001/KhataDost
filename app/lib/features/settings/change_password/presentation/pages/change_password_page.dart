import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:khata_dost/core/theme/app_theme.dart';

import '../../../../../core/widgets/app_snackbar.dart';
import '../../data/datasources/change_password_remote_datasource.dart';
import '../../data/repositories/change_password_repository_impl.dart';
import '../bloc/change_password_bloc.dart';
import '../bloc/change_password_event.dart';
import '../bloc/change_password_state.dart';

/// PLACEHOLDER page for the change-password flow, routed at
/// /settings/change-password.
///
/// Provides its own ChangePasswordBloc LOCALLY (not via GetIt) — move it to
/// injection.dart with a comment-swappable mock/remote datasource when you
/// wire the real PUT /v1/auth/password endpoint. The form is laid out; submit
/// currently surfaces a "not implemented" message from the stub datasource.
class ChangePasswordPage extends StatelessWidget {
  const ChangePasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ChangePasswordBloc>(
      create: (_) => ChangePasswordBloc(
        // TODO(you): swap in a real (comment-swappable) datasource.
        repository: ChangePasswordRepositoryImpl(
          const ChangePasswordRemoteDataSource(),
        ),
      ),
      child: const _ChangePasswordView(),
    );
  }
}

class _ChangePasswordView extends StatefulWidget {
  const _ChangePasswordView();

  @override
  State<_ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<_ChangePasswordView> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    // TODO(you): real validation — non-empty, new == confirm, min length —
    // before dispatching.
    context.read<ChangePasswordBloc>().add(
          SubmitRequested(
            currentPassword: _current.text,
            newPassword: _new.text,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: BlocConsumer<ChangePasswordBloc, ChangePasswordState>(
        listener: (context, state) {
          if (state.status == ChangePasswordStatus.failure) {
            AppSnackbar.error(
                context, state.errorMessage ?? 'Something went wrong.');
          } else if (state.status == ChangePasswordStatus.success) {
            AppSnackbar.success(context, 'Password updated.');
          }
        },
        builder: (context, state) {
          final submitting = state.status == ChangePasswordStatus.submitting;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Scaffold notice — remove when the endpoint goes live.
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 13, vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.warningSurface,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0xFFFDE4C8)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.construction_rounded,
                        size: 17, color: AppColors.warning),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This screen is a scaffold. Wire PUT /v1/auth/password '
                        'and real validation to make it live.',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: _current,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                  prefixIcon: Icon(Icons.lock_outline,
                      size: 21, color: AppColors.textHint),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _new,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New password',
                  prefixIcon: Icon(Icons.lock_reset_rounded,
                      size: 21, color: AppColors.textHint),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirm,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                  prefixIcon: Icon(Icons.lock_reset_rounded,
                      size: 21, color: AppColors.textHint),
                ),
              ),
              const SizedBox(height: 26),
              ElevatedButton(
                onPressed: submitting ? null : _submit,
                child: submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Update password'),
              ),
            ],
          );
        },
      ),
    );
  }
}
