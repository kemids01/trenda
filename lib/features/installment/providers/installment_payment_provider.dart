import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/providers.dart';
import 'installment_provider.dart';

/// Fetches payment schedule for a specific approved application
final installmentPaymentProvider =
    FutureProvider.family<Map<String, dynamic>?, String>(
        (ref, applicationId) async {
  final repo = ref.watch(installmentRepositoryProvider);
  final user = ref.watch(authNotifierProvider.select((state) => state.user));
  if (user == null) return null;

  final token = await user.getIdToken();
  return repo.getPaymentSchedule(applicationId, token!);
});
