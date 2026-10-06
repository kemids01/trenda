// lib/features/auth/data/resend_timer_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final otpResendTimerProvider =
    StateNotifierProvider<OtpResendTimerNotifier, int>(
  (_) => OtpResendTimerNotifier(),
);

class OtpResendTimerNotifier extends StateNotifier<int> {
  OtpResendTimerNotifier() : super(0);

  Timer? _timer;

  void startCountdown({int seconds = 30}) {
    _timer?.cancel();
    state = seconds;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state <= 1) {
        timer.cancel();
        state = 0;
      } else {
        state--;
      }
    });
  }

  void reset() {
    _timer?.cancel();
    state = 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
