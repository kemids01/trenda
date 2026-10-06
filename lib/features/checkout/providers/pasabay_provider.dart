// trenda_frontend/lib/features/checkout/providers/pasabay_provider.dart
// ============================================================================
// PASABAY STATE MANAGEMENT — Riverpod providers for batch delivery state
// ============================================================================
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenda_shared/core/config.dart';
import '../data/pasabay_repository.dart';
import '../logic/pasabay_tiers.dart';

// ── Repository helper ──────────────────────────────────────────

/// Async helper to build a repository with a fresh Firebase token.
Future<PasabayRepository> _freshRepo(Ref ref) async {
  final user = FirebaseAuth.instance.currentUser;
  final token = await user?.getIdToken() ?? '';
  return PasabayRepository(
    baseUrl: AppConfig.backendBaseUrl,
    getToken: () => token,
  );
}

// ── Active batches in customer's barangay ────────────────────────
final activeBatchesProvider = FutureProvider.family<PasabayBatchesResponse,
    ({String municipality, String barangay})>((ref, location) async {
  final repo = await _freshRepo(ref);
  return await repo.getActiveBatches(location.municipality, location.barangay);
});

// ── Fee preview for all batch types ──────────────────────────────
final pasabayFeePreviewProvider = FutureProvider.family<List<PasabayFeePreview>,
    ({String municipality, String barangay, double normalFee})>(
    (ref, params) async {
  final repo = await _freshRepo(ref);
  // Switched-off tiers are dropped here, so neither the picker nor the default
  // pick at submit can land on one (see activePreviews).
  return activePreviews(await repo.previewFees(
    municipality: params.municipality,
    barangay: params.barangay,
    normalDeliveryFee: params.normalFee,
  ));
});

// ── Batch details by ID ──────────────────────────────────────────
final batchDetailsProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, batchId) async {
  final repo = await _freshRepo(ref);
  return await repo.getBatchDetails(batchId);
});

// ── Join batch state (manages loading / error) ───────────────────
class JoinBatchState {
  final bool isLoading;
  final String? error;
  final PasabayJoinResult? result;

  const JoinBatchState({
    this.isLoading = false,
    this.error,
    this.result,
  });

  JoinBatchState copyWith({
    bool? isLoading,
    String? error,
    PasabayJoinResult? result,
  }) {
    return JoinBatchState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      result: result ?? this.result,
    );
  }
}

class JoinBatchNotifier extends StateNotifier<JoinBatchState> {
  final Ref _ref;

  JoinBatchNotifier(this._ref) : super(const JoinBatchState());

  Future<bool> joinBatch({
    required String orderId,
    required String municipality,
    required String barangay,
    String? batchTypeId,
    double? normalDeliveryFee,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final repo = await _freshRepo(_ref);
      final result = await repo.joinBatch(
        orderId: orderId,
        municipality: municipality,
        barangay: barangay,
        batchTypeId: batchTypeId,
        normalDeliveryFee: normalDeliveryFee,
      );
      state = JoinBatchState(isLoading: false, result: result);
      return result != null;
    } catch (e) {
      state = JoinBatchState(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> leaveBatch({
    required String batchId,
    required String orderId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final repo = await _freshRepo(_ref);
      final success = await repo.leaveBatch(batchId, orderId);
      state = const JoinBatchState(isLoading: false);
      return success;
    } catch (e) {
      state = JoinBatchState(isLoading: false, error: e.toString());
      return false;
    }
  }

  void reset() => state = const JoinBatchState();
}

final joinBatchProvider =
    StateNotifierProvider<JoinBatchNotifier, JoinBatchState>((ref) {
  return JoinBatchNotifier(ref);
});
