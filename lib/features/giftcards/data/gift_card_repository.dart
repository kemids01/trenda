// trenda_frontend/lib/features/giftcards/data/gift_card_repository.dart
//
// Customer-facing gift card API. Trenda funds and issues every card; a customer takes ownership by
// entering its code once (first-wins, irreversible), after which the balance is theirs to spend on
// GOODS at checkout — never the delivery fee.
//
// Canonical reference: trenda_backend/docs/GIFT_CARDS.md
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trenda_shared/core/config.dart';

/// Why a claim was refused. The UI shows a different message for each — "already claimed" and
/// "invalid code" need very different things from the customer.
enum ClaimFailure { notFound, alreadyClaimed, expired, cancelled, unauthenticated, network }

class ClaimResult {
  final bool ok;
  final ClaimFailure? failure;
  final Map<String, dynamic>? card;

  const ClaimResult.success(this.card) : ok = true, failure = null;
  const ClaimResult.failed(this.failure) : ok = false, card = null;
}

class GiftCardRepository {
  final Dio _dio;

  GiftCardRepository()
      : _dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.backendBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 30),
            // Claim failures are meaningful responses, not transport errors — read the status
            // ourselves instead of having Dio throw on 4xx.
            validateStatus: (s) => s != null && s < 500,
          ),
        );

  Future<Map<String, String>> _getAuthHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');
    final token = await user.getIdToken();
    return {'Authorization': 'Bearer $token'};
  }

  /// Cards this customer has claimed.
  ///
  /// `/mine` filters on `claimedBy`. The old `/my-cards` filtered on `purchasedBy`, which is never
  /// set on a Trenda-funded card — it always returned nothing.
  Future<List<Map<String, dynamic>>> getMyCards() async {
    final headers = await _getAuthHeaders();
    final response = await _dio.get(
      '/api/gift-cards/mine',
      options: Options(headers: headers),
    );
    final data = response.data?['data'];
    if (data is! List) return const [];
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Claim a card by code. First-wins and irreversible — once claimed the balance is locked to
  /// this account and cannot be transferred.
  Future<ClaimResult> claim(String code) async {
    final Map<String, String> headers;
    try {
      headers = await _getAuthHeaders();
    } catch (_) {
      return const ClaimResult.failed(ClaimFailure.unauthenticated);
    }

    try {
      final response = await _dio.post(
        '/api/gift-cards/claim',
        data: {'code': code.trim().toUpperCase()},
        options: Options(headers: headers),
      );

      final status = response.statusCode ?? 500;
      if (status == 200 || status == 201) {
        final card = response.data?['data'];
        return ClaimResult.success(card is Map ? Map<String, dynamic>.from(card) : null);
      }

      switch (status) {
        case 404:
          return const ClaimResult.failed(ClaimFailure.notFound);
        case 409:
          return const ClaimResult.failed(ClaimFailure.alreadyClaimed);
        case 400:
          // The server distinguishes expired from cancelled in the message text.
          final msg = (response.data?['message'] ?? '').toString().toLowerCase();
          if (msg.contains('expired')) return const ClaimResult.failed(ClaimFailure.expired);
          return const ClaimResult.failed(ClaimFailure.cancelled);
        default:
          return const ClaimResult.failed(ClaimFailure.network);
      }
    } on DioException {
      return const ClaimResult.failed(ClaimFailure.network);
    }
  }
}
