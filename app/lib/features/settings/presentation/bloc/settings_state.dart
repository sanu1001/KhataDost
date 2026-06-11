import 'package:equatable/equatable.dart';
import '../../domain/entities/shop_profile.dart';

/// What "phase" the profile fetch is in right now.
enum SettingsStatus { initial, loading, loaded, failure }

/// Single state class — no sealed variants (matches the four built features).
/// The BLoC emits copies via copyWith() to update individual fields.
class SettingsState extends Equatable {
  const SettingsState({
    this.status = SettingsStatus.initial,
    this.profile,
    this.errorMessage,
  });

  final SettingsStatus status;

  /// Non-null when status == loaded.
  final ShopProfile? profile;

  /// Non-null when status == failure.
  final String? errorMessage;

  bool get isLoading => status == SettingsStatus.loading;
  bool get isLoaded => status == SettingsStatus.loaded;
  bool get hasError => status == SettingsStatus.failure;

  SettingsState copyWith({
    SettingsStatus? status,
    ShopProfile? profile,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SettingsState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, profile, errorMessage];
}
