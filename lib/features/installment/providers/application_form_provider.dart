import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenda_shared/models/installment_model.dart';
import '../../auth/data/providers.dart';
import '../providers/installment_provider.dart';

// State for the wizard form
class InstallmentFormState {
  final int currentStep;
  final bool isLoading;
  final String? errorMessage;
  final Map<String, dynamic> formData;
  final InstallmentApplication? submittedApplication;
  final bool hasSavedData;

  const InstallmentFormState({
    this.currentStep = 0,
    this.isLoading = false,
    this.errorMessage,
    this.formData = const {},
    this.submittedApplication,
    this.hasSavedData = false,
  });

  InstallmentFormState copyWith({
    int? currentStep,
    bool? isLoading,
    String? errorMessage,
    Map<String, dynamic>? formData,
    InstallmentApplication? submittedApplication,
    bool? hasSavedData,
  }) {
    return InstallmentFormState(
      currentStep: currentStep ?? this.currentStep,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      formData: formData ?? this.formData,
      submittedApplication: submittedApplication ?? this.submittedApplication,
      hasSavedData: hasSavedData ?? this.hasSavedData,
    );
  }
}

// Notifier to handle form logic
class InstallmentFormNotifier extends StateNotifier<InstallmentFormState> {
  final Ref ref;

  InstallmentFormNotifier(this.ref) : super(const InstallmentFormState());

  // Initialize with draft data (e.g. from calculator)
  void initialize(Map<String, dynamic>? draft) {
    if (draft != null) {
      state = state.copyWith(formData: {...state.formData, ...draft});
    }
  }

  /// Load previously saved form data (personal info, address, etc.)
  Future<void> loadSavedForm() async {
    try {
      final user = ref.read(authNotifierProvider).user;
      if (user == null) return;
      final token = await user.getIdToken();
      if (token == null) return;

      final repo = ref.read(installmentRepositoryProvider);
      final savedData = await repo.getSavedFormDraft(token);

      if (savedData != null && savedData.isNotEmpty) {
        // Merge saved personal data into formData (don't overwrite plan/product keys)
        final currentData = Map<String, dynamic>.from(state.formData);
        final reusableKeys = [
          'personalInfo',
          'spouseInfo',
          'addressInfo',
          'housingInfo',
          'references',
          'dependents',
          'incomeInfo',
          'expensesInfo',
        ];
        for (final key in reusableKeys) {
          if (savedData.containsKey(key) && savedData[key] != null) {
            currentData[key] = savedData[key];
          }
        }
        state = state.copyWith(formData: currentData, hasSavedData: true);
      }
    } catch (_) {
      // Silently fail — saved form is optional
    }
  }

  /// Save personal form sections for future reuse
  Future<void> _saveFormForReuse() async {
    try {
      final user = ref.read(authNotifierProvider).user;
      if (user == null) return;
      final token = await user.getIdToken();
      if (token == null) return;

      final repo = ref.read(installmentRepositoryProvider);
      final dataToSave = <String, dynamic>{};
      final reusableKeys = [
        'personalInfo',
        'spouseInfo',
        'addressInfo',
        'housingInfo',
        'references',
        'dependents',
        'incomeInfo',
        'expensesInfo',
      ];
      for (final key in reusableKeys) {
        if (state.formData.containsKey(key)) {
          dataToSave[key] = state.formData[key];
        }
      }
      if (dataToSave.isNotEmpty) {
        await repo.saveFormDraft(dataToSave, token);
      }
    } catch (_) {
      // Non-critical — don't block submission
    }
  }

  String? validateCurrentStep() {
    final data = state.formData;
    final step = state.currentStep;

    switch (step) {
      case 0:
        return null; // read-only summary

      case 1: // Personal Info
        final p = data['personalInfo'] as Map<String, dynamic>? ?? {};
        if ((p['firstName'] ?? '').toString().trim().isEmpty) {
          return 'First name is required';
        }
        if ((p['lastName'] ?? '').toString().trim().isEmpty) {
          return 'Last name is required';
        }
        if ((p['mobileNumber'] ?? '').toString().trim().isEmpty) {
          return 'Mobile number is required';
        }
        if (p['dateOfBirth'] == null) {
          return 'Date of birth is required';
        }
        return null;

      case 2: // Selfie
        final p = data['personalInfo'] as Map<String, dynamic>? ?? {};
        if ((p['photoUrl'] ?? '').toString().isEmpty) {
          return 'Please take a selfie photo';
        }
        return null;

      case 3: // Valid ID
        final p = data['personalInfo'] as Map<String, dynamic>? ?? {};
        if ((p['validIdFrontUrl'] ?? '').toString().isEmpty) {
          return 'Please upload the front of your valid ID';
        }
        if ((p['validIdBackUrl'] ?? '').toString().isEmpty) {
          return 'Please upload the back of your valid ID';
        }
        return null;

      case 4: // Address
        final a = data['addressInfo'] as Map<String, dynamic>? ?? {};
        if ((a['province'] ?? '').toString().trim().isEmpty) {
          return 'Province is required';
        }
        if ((a['municipality'] ?? '').toString().trim().isEmpty) {
          return 'Municipality / City is required';
        }
        if ((a['barangay'] ?? '').toString().trim().isEmpty) {
          return 'Barangay is required';
        }
        return null;

      case 5: // Housing — has defaults, no strict validation
        return null;

      case 6: // References
        final refs = data['references'] as List? ?? [];
        bool hasValid = false;
        for (final ref in refs) {
          if (ref is Map) {
            final name = (ref['name'] ?? '').toString().trim();
            final contact = (ref['contact'] ?? '').toString().trim();
            if (name.isNotEmpty && contact.isNotEmpty) {
              hasValid = true;
              break;
            }
          }
        }
        if (!hasValid) {
          return 'At least 1 reference with name and contact is required';
        }
        return null;

      case 7: // Household — defaults to 0, OK
        return null;

      case 8: // Employment & Income
        final inc = data['incomeInfo'] as Map<String, dynamic>? ?? {};
        if ((inc['employerName'] ?? '').toString().trim().isEmpty) {
          return 'Employer / Business name is required';
        }
        final salary = (inc['monthlyIncome'] ?? 0);
        if ((salary is num && salary <= 0) ||
            (salary is String && (double.tryParse(salary) ?? 0) <= 0)) {
          return 'Monthly income must be greater than 0';
        }
        return null;

      case 9: // Spouse (optional)
        final sp = data['spouseInfo'] as Map<String, dynamic>? ?? {};
        if (sp['hasSpouse'] == true) {
          if ((sp['name'] ?? '').toString().trim().isEmpty) {
            return 'Spouse name is required';
          }
        }
        return null;

      case 10: // Expenses
        final exp = data['expensesInfo'] as Map<String, dynamic>? ?? {};
        final total = (exp['totalExpenses'] ?? 0);
        if ((total is num && total <= 0) ||
            (total is String && (double.tryParse(total) ?? 0) <= 0)) {
          return 'Please fill in at least one expense';
        }
        return null;

      case 11: // Authorization
        final auth = data['authorization'] as Map<String, dynamic>? ?? {};
        if (auth['certify'] != true) {
          return 'You must certify that all information is true';
        }
        if (auth['agreeTerms'] != true) {
          return 'You must agree to the Terms & Conditions';
        }
        if ((auth['signatureName'] ?? '').toString().trim().isEmpty) {
          return 'Digital signature (full name) is required';
        }
        return null;

      case 12: // Review — no validation
        return null;

      default:
        return null;
    }
  }

  void nextStep() {
    final error = validateCurrentStep();
    if (error != null) {
      state = state.copyWith(errorMessage: error);
      return;
    }
    if (state.currentStep < 12) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  void updateSection(String section, Map<String, dynamic> data) {
    final currentData = Map<String, dynamic>.from(state.formData);
    if (currentData.containsKey(section) && currentData[section] is Map) {
      currentData[section] = {...currentData[section], ...data};
    } else {
      currentData[section] = data;
    }
    state = state.copyWith(formData: currentData);
  }

  void updateRoot(String key, dynamic value) {
    final currentData = Map<String, dynamic>.from(state.formData);
    currentData[key] = value;
    state = state.copyWith(formData: currentData);
  }

  Future<void> submitApplication() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final controller = ref.read(installmentControllerProvider);

      if (state.formData['productId'] == null ||
          state.formData['planId'] == null) {
        throw Exception('Missing product or plan information');
      }

      final application = await controller.submitApplication(state.formData);

      // Save form data for future applications
      await _saveFormForReuse();

      state =
          state.copyWith(isLoading: false, submittedApplication: application);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}

final installmentFormProvider = StateNotifierProvider.autoDispose<
    InstallmentFormNotifier, InstallmentFormState>((ref) {
  return InstallmentFormNotifier(ref);
});
