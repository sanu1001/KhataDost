import 'package:equatable/equatable.dart';

enum ChangePasswordStatus { initial, submitting, success, failure }

/// Single state class + copyWith (matches the built features' bloc pattern).
class ChangePasswordState extends Equatable {
  const ChangePasswordState({
    this.status = ChangePasswordStatus.initial,
    this.errorMessage,
  });

  final ChangePasswordStatus status;
  final String? errorMessage;

  ChangePasswordState copyWith({
    ChangePasswordStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ChangePasswordState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, errorMessage];
}
