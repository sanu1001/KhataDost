import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:khata_dost/core/theme/app_theme.dart';

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
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage ?? 'Something went wrong.'),
                ),
              );
          } else if (state.status == ChangePasswordStatus.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Password updated.')),
            );
          }
        },
        builder: (context, state) {
          final submitting = state.status == ChangePasswordStatus.submitting;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'This screen is a scaffold. Wire PUT /v1/auth/password and real '
                'validation to make it live.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _current,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Current password'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _new,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirm,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Confirm new password'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: submitting ? null : _submit,
                child: Text(submitting ? 'Updating…' : 'Update password'),
              ),
            ],
          );
        },
      ),
    );
  }
}
