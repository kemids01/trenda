import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenda_shared/models/installment_model.dart';
import 'package:trenda_shared/core/config.dart';
import '../data/installment_repository.dart';
import '../../auth/data/providers.dart';

final installmentRepositoryProvider = Provider<InstallmentRepository>((ref) {
  return InstallmentRepository(baseUrl: AppConfig.backendBaseUrl);
});

// Fetch plans for a specific product
final productInstallmentPlansProvider =
    FutureProvider.family<List<InstallmentPlan>, String>(
        (ref, productId) async {
  final repo = ref.watch(installmentRepositoryProvider);
  final user = ref.watch(authNotifierProvider.select((state) => state.user));

  String? token;
  if (user != null) {
    token = await user.getIdToken();
  }

  return repo.getPlansForProduct(productId, token: token);
});

// Fetch customer's applications
// Fetch customer's applications
final customerApplicationsProvider =
    FutureProvider<List<InstallmentApplication>>((ref) async {
  final repo = ref.watch(installmentRepositoryProvider);
  final user = ref.watch(authNotifierProvider.select((state) => state.user));

  if (user == null) return [];

  final token = await user.getIdToken();
  return repo.getMyApplications(token!);
});

// Controller for submitting applications (could be a notifier if complex state needed)
final installmentControllerProvider = Provider<InstallmentController>((ref) {
  return InstallmentController(ref);
});

class InstallmentController {
  final Ref _ref;
  InstallmentController(this._ref);

  Future<InstallmentApplication> submitApplication(
      Map<String, dynamic> data) async {
    final repo = _ref.read(installmentRepositoryProvider);
    final user = _ref.read(authNotifierProvider).user;

    if (user == null) throw Exception('User not authenticated');

    final token = await user.getIdToken();
    return repo.submitApplication(data, token!);
  }
}
