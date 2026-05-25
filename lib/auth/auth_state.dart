import 'user_model.dart';

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final bool isRestoring;
  final String? error;
  final UserModel? user;
  final String? pendingSessionToken;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.isRestoring = true,
    this.error,
    this.user,
    this.pendingSessionToken,
  });

  bool get requiresOtp => pendingSessionToken != null && !isAuthenticated;

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    bool? isRestoring,
    String? error,
    bool clearError = false,
    UserModel? user,
    String? pendingSessionToken,
    bool clearPendingSession = false,
  }) =>
      AuthState(
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        isLoading: isLoading ?? this.isLoading,
        isRestoring: isRestoring ?? this.isRestoring,
        error: clearError ? null : (error ?? this.error),
        user: user ?? this.user,
        pendingSessionToken: clearPendingSession
            ? null
            : (pendingSessionToken ?? this.pendingSessionToken),
      );
}
