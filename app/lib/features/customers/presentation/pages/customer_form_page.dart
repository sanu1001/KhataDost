import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/navigation/navigation_cubit.dart';
import '../bloc/customers_bloc.dart';
import '../bloc/customers_event.dart';
import '../bloc/customers_state.dart';

class CustomerFormPage extends StatefulWidget {
  /// null → add mode.  non-null → edit mode.
  final String? customerId;

  const CustomerFormPage({super.key, this.customerId});

  bool get isEditMode => customerId != null;

  @override
  State<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends State<CustomerFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _notesController;

  bool _isSubmitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();

    // In edit mode: look up the customer from current bloc state to pre-fill.
    // The bloc is already loaded by the time detail→edit push happens.
    final existing = widget.isEditMode
        ? context
        .read<CustomersBloc>()
        .state
        .customers
        .firstWhere((c) => c.id == widget.customerId,
        orElse: () => throw StateError('Customer not in state'))
        : null;

    _nameController  = TextEditingController(text: existing?.name  ?? '');
    _phoneController = TextEditingController(text: existing?.phone ?? '');
    _emailController = TextEditingController(text: existing?.email ?? '');
    _notesController = TextEditingController(text: existing?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    // Step 1: run form validators — bail if any field is invalid.
    if (!_formKey.currentState!.validate()) return;

    // Step 2: mark submitting — the BlocListener uses this flag.
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    // Step 3: normalize values — trim whitespace, convert empty optionals to null.
    final name  = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim().isEmpty
        ? null
        : _emailController.text.trim();
    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();

    // Step 4: dispatch the right event based on mode.
    if (widget.isEditMode) {
      context.read<CustomersBloc>().add(CustomerUpdated(
        id: widget.customerId!,
        name: name,
        phone: phone,
        email: email,
        notes: notes,
      ));
    } else {
      context.read<CustomersBloc>().add(CustomerAdded(
        name: name,
        phone: phone,
        email: email,
        notes: notes,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CustomersBloc, CustomersState>(
      listener: (context, state) {
        // Only react during an active submission.
        if (!_isSubmitting) return;

        if (state.errorMessage != null) {
          // Mutation failed — surface the error inline, stop the spinner.
          setState(() {
            _isSubmitting = false;
            _submitError = state.errorMessage;
          });
        } else if (state.status == CustomersStatus.loaded) {
          // Mutation succeeded (errorMessage is null, list updated) — pop.
          setState(() => _isSubmitting = false);
          context.read<NavigationCubit>().goBack();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isEditMode ? 'Edit Customer' : 'Add Customer'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.read<NavigationCubit>().goBack(),
          ),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Phone is required'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email (optional)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                // Inline submission error (mutation failed).
                if (_submitError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _submitError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Text(widget.isEditMode
                      ? 'Save changes'
                      : 'Add customer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}