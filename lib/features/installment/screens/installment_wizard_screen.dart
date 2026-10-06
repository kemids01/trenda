import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/application_form_provider.dart';
import '../widgets/wizard_steps/step_01_details.dart';
import '../widgets/wizard_steps/step_02_personal.dart';
import '../widgets/wizard_steps/step_03_selfie.dart';
import '../widgets/wizard_steps/step_04_valid_id.dart';
import '../widgets/wizard_steps/step_03_address.dart';
import '../widgets/wizard_steps/step_04_employment.dart';
import '../widgets/wizard_steps/step_05_housing.dart';
import '../widgets/wizard_steps/step_06_references.dart';
import '../widgets/wizard_steps/step_07_household.dart';
import '../widgets/wizard_steps/step_08_expenses.dart';
import '../widgets/wizard_steps/step_09_spouse.dart';
import '../widgets/wizard_steps/step_11_authorization.dart';
import '../widgets/wizard_steps/step_12_review.dart';

class InstallmentWizardScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? draftApplication;

  const InstallmentWizardScreen({super.key, this.draftApplication});

  @override
  ConsumerState<InstallmentWizardScreen> createState() =>
      _InstallmentWizardScreenState();
}

class _InstallmentWizardScreenState
    extends ConsumerState<InstallmentWizardScreen> {
  bool _savedDataBannerDismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(installmentFormProvider.notifier);
      notifier.initialize(widget.draftApplication);
      // Load previously saved personal info from prior applications
      notifier.loadSavedForm();
    });
  }

  Future<void> _confirmExit(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Application?'),
        content: const Text('Your progress will be lost.'),
        actions: [
          TextButton(
              onPressed: () => context.pop(false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => context.pop(true), child: const Text('Discard')),
        ],
      ),
    );
    if (confirm == true && mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/main');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(installmentFormProvider);
    final notifier = ref.read(installmentFormProvider.notifier);

    // Listen for submission success
    ref.listen(installmentFormProvider, (prev, next) {
      if (next.submittedApplication != null && next.errorMessage == null) {
        // Navigate to success page or my applications
        context.go('/installment/my-applications');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application Submitted Successfully!')),
        );
      }
      if (next.errorMessage != null &&
          (prev?.errorMessage != next.errorMessage)) {
        if (next.errorMessage!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error: ${next.errorMessage}'),
                backgroundColor: Colors.red),
          );
        }
      }
    });

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _confirmExit(context);
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: Text(
            _stepLabel(formState.currentStep),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => _confirmExit(context),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(
                child: Text(
                  '${formState.currentStep + 1}/13',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600),
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3.0),
            child: LinearProgressIndicator(
              value: (formState.currentStep + 1) / 13,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              minHeight: 3,
            ),
          ),
        ),
        body: Column(
          children: [
            // Saved data notification banner
            if (formState.hasSavedData && !_savedDataBannerDismissed)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: Colors.blue.shade50,
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pre-filled from your previous application. Review & update as needed.',
                        style: TextStyle(
                            fontSize: 11, color: Colors.blue.shade800),
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _savedDataBannerDismissed = true),
                      child: Icon(Icons.close,
                          size: 16, color: Colors.blue.shade400),
                    ),
                  ],
                ),
              ),

            // Build Step Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: _buildStepContent(formState.currentStep),
              ),
            ),

            // Navigation Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 6,
                      offset: const Offset(0, -2)),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    if (formState.currentStep > 0)
                      OutlinedButton.icon(
                        onPressed:
                            formState.isLoading ? null : notifier.previousStep,
                        icon: const Icon(Icons.arrow_back_ios, size: 14),
                        label:
                            const Text('Back', style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: formState.isLoading
                          ? null
                          : () {
                              if (formState.currentStep == 12) {
                                notifier.submitApplication();
                              } else {
                                notifier.nextStep();
                              }
                            },
                      icon: formState.isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Icon(
                              formState.currentStep == 12
                                  ? Icons.send
                                  : Icons.arrow_forward_ios,
                              size: 14),
                      label: Text(
                          formState.currentStep == 12
                              ? 'Submit Application'
                              : 'Next',
                          style: const TextStyle(fontSize: 13)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _stepLabel(int step) {
    const labels = [
      'Application Summary',
      'Personal Info',
      'Selfie Verification',
      'Valid ID Upload',
      'Address',
      'Housing',
      'References',
      'Household',
      'Employment & Income',
      'Spouse Info',
      'Monthly Expenses',
      'Authorization',
      'Final Review',
    ];
    return step < labels.length ? labels[step] : 'Step ${step + 1}';
  }

  Widget _buildStepContent(int step) {
    switch (step) {
      case 0:
        return const Step01Details();
      case 1:
        return const Step02Personal();
      case 2:
        return const Step03Selfie();
      case 3:
        return const Step04ValidId();
      case 4:
        return const Step05Address();
      case 5:
        return const Step05Housing();
      case 6:
        return const Step06References();
      case 7:
        return const Step07Household();
      case 8:
        return const Step04Employment();
      case 9:
        return const Step09Spouse();
      case 10:
        return const Step08Expenses();
      case 11:
        return const Step11Authorization();
      case 12:
        return const Step12Review();
      default:
        return const Center(child: Text('Unknown Step'));
    }
  }
}
