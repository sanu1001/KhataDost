import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/auth_bloc.dart';
import '../../bloc/auth_event.dart';
import '../../bloc/auth_state.dart';
import 'auth_text_field.dart';

class RegisterForm extends StatefulWidget {
  const RegisterForm({super.key});

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl       = TextEditingController();
  final _shopNameCtrl   = TextEditingController();
  final _phoneCtrl      = TextEditingController();
  final _emailCtrl      = TextEditingController();
  final _passwordCtrl   = TextEditingController();
  final _confirmPwCtrl  = TextEditingController();
  final _accessCodeCtrl = TextEditingController();

  final _nameFocus       = FocusNode();
  final _shopNameFocus   = FocusNode();
  final _phoneFocus      = FocusNode();
  final _emailFocus      = FocusNode();
  final _passwordFocus   = FocusNode();
  final _confirmPwFocus  = FocusNode();
  final _accessCodeFocus = FocusNode();

  @override
  void dispose() {
    _nameCtrl.dispose(); _shopNameCtrl.dispose();
    _phoneCtrl.dispose(); _emailCtrl.dispose();
    _passwordCtrl.dispose(); _confirmPwCtrl.dispose();
    _accessCodeCtrl.dispose();
    _nameFocus.dispose(); _shopNameFocus.dispose();
    _phoneFocus.dispose(); _emailFocus.dispose();
    _passwordFocus.dispose(); _confirmPwFocus.dispose();
    _accessCodeFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    context.read<AuthBloc>().add(RegisterRequested(
      name: _nameCtrl.text.trim(),
      shopName: _shopNameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      accessCode: _accessCodeCtrl.text.trim(),
    ));
  }

  String? _required(String? v, String field) =>
      (v == null || v.trim().isEmpty) ? '$field is required' : null;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Name
              AuthTextField(
                controller: _nameCtrl, focusNode: _nameFocus,
                label: 'Your name', hint: 'Ramesh Kumar',
                prefixIcon: Icons.person_outline,
                autofillHints: const [AutofillHints.name],
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_shopNameFocus),
                validator: (v) => _required(v, 'Name'),
              ),
              const SizedBox(height: 16),

              // Shop name
              AuthTextField(
                controller: _shopNameCtrl, focusNode: _shopNameFocus,
                label: 'Shop name', hint: 'Ramesh Kirana Store',
                prefixIcon: Icons.storefront_outlined,
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_phoneFocus),
                validator: (v) => _required(v, 'Shop name'),
              ),
              const SizedBox(height: 16),

              // Phone
              AuthTextField(
                controller: _phoneCtrl, focusNode: _phoneFocus,
                label: 'Phone number', hint: '9876543210',
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_outlined,
                maxLength: 10,
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_emailFocus),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Phone is required';
                  if (v.trim().length != 10) return 'Enter a 10-digit number';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email
              AuthTextField(
                controller: _emailCtrl, focusNode: _emailFocus,
                label: 'Email', hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.email_outlined,
                autofillHints: const [AutofillHints.newUsername],
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_passwordFocus),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Password
              AuthTextField(
                controller: _passwordCtrl, focusNode: _passwordFocus,
                label: 'Password', obscure: true,
                prefixIcon: Icons.lock_outline,
                autofillHints: const [AutofillHints.newPassword],
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_confirmPwFocus),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required';
                  if (v.length < 6) return 'At least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Confirm password
              AuthTextField(
                controller: _confirmPwCtrl, focusNode: _confirmPwFocus,
                label: 'Confirm password', obscure: true,
                prefixIcon: Icons.lock_outline,
                autofillHints: const [AutofillHints.newPassword],
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_accessCodeFocus),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please confirm your password';
                  if (v != _passwordCtrl.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Access code
              AuthTextField(
                controller: _accessCodeCtrl, focusNode: _accessCodeFocus,
                label: 'Access code', hint: 'Provided by KhataDost team',
                prefixIcon: Icons.vpn_key_outlined,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: (v) => _required(v, 'Access code'),
              ),

              // Inline error
              if (state.hasError && state.errorMessage != null) ...[
                const SizedBox(height: 12),
                _ErrorBanner(message: state.errorMessage!),
              ],

              const SizedBox(height: 20),

              FilledButton(
                onPressed: state.isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
                child: state.isLoading
                    ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Text('Create account'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    color: scheme.onErrorContainer, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}