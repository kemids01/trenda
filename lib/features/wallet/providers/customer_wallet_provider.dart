// trenda_frontend/lib/features/wallet/providers/customer_wallet_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/customer_wallet_repository.dart';

// Repository provider
final customerWalletRepositoryProvider = Provider<CustomerWalletRepository>(
  (ref) => CustomerWalletRepository(),
);

// ============================================================================
// WALLET DATA PROVIDER
// ============================================================================

/// Customer wallet balance + recent transactions
final customerWalletProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(customerWalletRepositoryProvider);
  return repo.getWallet(transactionLimit: 10);
});

// ============================================================================
// PAYMENT METHODS
// ============================================================================

final activePaymentMethodsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(customerWalletRepositoryProvider);
  return repo.getActivePaymentMethods();
});

// ============================================================================
// RECHARGE HISTORY
// ============================================================================

class RechargeHistoryState {
  final List<Map<String, dynamic>> requests;
  final Map<String, dynamic> pagination;
  final bool isLoading;
  final String? error;
  final int currentPage;

  RechargeHistoryState({
    this.requests = const [],
    this.pagination = const {},
    this.isLoading = false,
    this.error,
    this.currentPage = 1,
  });

  RechargeHistoryState copyWith({
    List<Map<String, dynamic>>? requests,
    Map<String, dynamic>? pagination,
    bool? isLoading,
    String? error,
    int? currentPage,
  }) {
    return RechargeHistoryState(
      requests: requests ?? this.requests,
      pagination: pagination ?? this.pagination,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class RechargeHistoryNotifier extends StateNotifier<RechargeHistoryState> {
  final CustomerWalletRepository _repo;

  RechargeHistoryNotifier(this._repo) : super(RechargeHistoryState());

  Future<void> loadHistory({int page = 1}) async {
    state = state.copyWith(isLoading: true, error: null, currentPage: page);
    try {
      final result = await _repo.getRechargeHistory(page: page);
      state = state.copyWith(
        requests: result['requests'] as List<Map<String, dynamic>>,
        pagination: result['pagination'] as Map<String, dynamic>,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final rechargeHistoryProvider = StateNotifierProvider.autoDispose<
    RechargeHistoryNotifier, RechargeHistoryState>((ref) {
  final repo = ref.watch(customerWalletRepositoryProvider);
  final notifier = RechargeHistoryNotifier(repo);
  notifier.loadHistory();
  return notifier;
});

// ============================================================================
// RECHARGE REQUEST STATE
// ============================================================================

class RechargeRequestState {
  final bool isSubmitting;
  final String? error;
  final Map<String, dynamic>? result;

  RechargeRequestState({
    this.isSubmitting = false,
    this.error,
    this.result,
  });

  RechargeRequestState copyWith({
    bool? isSubmitting,
    String? error,
    Map<String, dynamic>? result,
  }) {
    return RechargeRequestState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
      result: result,
    );
  }
}

class RechargeRequestNotifier extends StateNotifier<RechargeRequestState> {
  final CustomerWalletRepository _repo;
  final Ref _ref;

  RechargeRequestNotifier(this._repo, this._ref)
      : super(RechargeRequestState());

  Future<bool> submitRequest({
    required double amount,
    required String paymentMethodId,
    required String receiptImage,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null, result: null);
    try {
      final result = await _repo.createRechargeRequest(
        amount: amount,
        paymentMethodId: paymentMethodId,
        receiptImage: receiptImage,
      );
      state = state.copyWith(isSubmitting: false, result: result);
      _ref.invalidate(rechargeHistoryProvider);
      _ref.invalidate(customerWalletProvider);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }

  void reset() {
    state = RechargeRequestState();
  }
}

final rechargeRequestProvider = StateNotifierProvider.autoDispose<
    RechargeRequestNotifier, RechargeRequestState>((ref) {
  final repo = ref.watch(customerWalletRepositoryProvider);
  return RechargeRequestNotifier(repo, ref);
});
