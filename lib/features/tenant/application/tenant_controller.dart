import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/injection.dart';
import '../../../core/tenant/tenant_code_storage.dart';
import '../domain/entities/tenant_lookup.dart';
import '../domain/repositories/tenant_repository.dart';

class TenantState {
  const TenantState({
    this.code,
    this.lookup,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final String? code;
  final TenantLookup? lookup;
  final bool isSubmitting;
  final String? errorMessage;

  bool get hasCode => code != null && code!.isNotEmpty;

  TenantState copyWith({
    String? code,
    TenantLookup? lookup,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    bool clearLookup = false,
    bool clearCode = false,
  }) {
    return TenantState(
      code: clearCode ? null : (code ?? this.code),
      lookup: clearLookup ? null : (lookup ?? this.lookup),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class TenantController extends Notifier<TenantState> {
  late final TenantCodeStorage _storage;
  late final TenantRepository _repo;

  @override
  TenantState build() {
    _storage = sl<TenantCodeStorage>();
    _repo = sl<TenantRepository>();
    final code = _storage.get();
    if (code != null && code.isNotEmpty) {
      // Refresh the lookup in the background so the login page can show the
      // tenant name/logo. Failures here are non-blocking — the seller can
      // still log in even if the lookup 500s or the network is flaky.
      Future.microtask(() => _refreshLookup(code));
      return TenantState(code: code);
    }
    return const TenantState();
  }

  Future<void> _refreshLookup(String code) async {
    final result = await _repo.lookup(code);
    result.match(
      (_) {}, // ignore — non-blocking
      (lookup) => state = state.copyWith(lookup: lookup),
    );
  }

  /// Validates [code] against the backend and, on success, persists it and
  /// updates state. Returns true when the code is accepted.
  Future<bool> submitCode(String code) async {
    final normalized = code.trim().toLowerCase();
    if (normalized.isEmpty) {
      state = state.copyWith(errorMessage: 'Ingresa un código');
      return false;
    }
    state = state.copyWith(isSubmitting: true, clearError: true);
    final result = await _repo.lookup(normalized);
    return await result.match(
      (failure) async {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: failure.message,
        );
        return false;
      },
      (lookup) async {
        if (!lookup.isActive) {
          state = state.copyWith(
            isSubmitting: false,
            errorMessage:
                'Esta sucursal está inactiva. Contacta al administrador.',
          );
          return false;
        }
        await _storage.set(normalized);
        state = state.copyWith(
          code: normalized,
          lookup: lookup,
          isSubmitting: false,
        );
        return true;
      },
    );
  }

  Future<void> clear() async {
    await _storage.clear();
    state = const TenantState();
  }
}

final tenantControllerProvider =
    NotifierProvider<TenantController, TenantState>(TenantController.new);
