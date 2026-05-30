import 'package:equatable/equatable.dart';

abstract class CustomersEvent extends Equatable {
  const CustomersEvent();

  @override
  List<Object?> get props => [];
}

/// Fired on tab focus — load the full list from the repository.
class CustomersLoadRequested extends CustomersEvent {
  const CustomersLoadRequested();
}

/// Fired by the form in "add" mode.
class CustomerAdded extends CustomersEvent {
  final String name;
  final String phone;
  final String? email;
  final String? notes;

  const CustomerAdded({
    required this.name,
    required this.phone,
    this.email,
    this.notes,
  });

  @override
  List<Object?> get props => [name, phone, email, notes];
}

/// Fired by the form in "edit" mode — carries the id of the row to replace.
class CustomerUpdated extends CustomersEvent {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? notes;

  const CustomerUpdated({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.notes,
  });

  @override
  List<Object?> get props => [id, name, phone, email, notes];
}

/// Fired by the delete button (only rendered when hasDues == false).
class CustomerDeleted extends CustomersEvent {
  final String id;
  const CustomerDeleted(this.id);

  @override
  List<Object?> get props => [id];
}

/// Fired on every keystroke in the search bar.
class CustomerSearchChanged extends CustomersEvent {
  final String query;
  const CustomerSearchChanged(this.query);

  @override
  List<Object?> get props => [query];
}