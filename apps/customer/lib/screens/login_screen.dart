import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import 'otp_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  String get _e164 => '+91${_phoneCtrl.text.trim()}';

  Future<void> _continue() async {
    final digits = _phoneCtrl.text.trim();
    if (digits.length != 10) {
      _snack('Enter a valid 10-digit mobile number');
      return;
    }
    setState(() => _loading = true);
    final auth = ref.read(authServiceProvider);
    // Watchdog: device verification for real numbers can stall silently on
    // sideloaded dev builds. Don't spin forever — guide the user instead.
    var handled = false;
    Future.delayed(const Duration(seconds: 30), () {
      if (!mounted || handled) return;
      setState(() => _loading = false);
      _snack('Taking too long. On this dev build, use the test number '
          '9000000001 (OTP 123456).');
    });
    try {
      await auth.sendOtp(
        phoneNumber: _e164,
        onCodeSent: (verificationId) {
          handled = true;
          if (!mounted) return;
          setState(() => _loading = false);
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => OtpScreen(
              verificationId: verificationId,
              phoneNumber: _e164,
            ),
          ));
        },
        onError: (e) {
          handled = true;
          if (!mounted) return;
          setState(() => _loading = false);
          _snack(AuthService.friendlyError(e));
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Something went wrong: $e');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const FadeSlideIn(
                child: _LogoMark(),
              ),
              const SizedBox(height: 24),
              const FadeSlideIn(
                delay: Duration(milliseconds: 80),
                child: Text('Flowzaa', style: AppText.display),
              ),
              const SizedBox(height: 10),
              FadeSlideIn(
                delay: const Duration(milliseconds: 160),
                child: RichText(
                  text: TextSpan(
                    style: AppText.bodySoft,
                    children: [
                      const TextSpan(
                          text:
                              'Book bikes, autos, cars & parcels in seconds.\nFlowzaa takes '),
                      TextSpan(
                        text: '0%',
                        style: AppText.bodySoft.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const TextSpan(
                          text: ' — you pay your captain directly.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),
              FadeSlideIn(
                delay: const Duration(milliseconds: 240),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Mobile number', style: AppText.label),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        counterText: '',
                        prefixIcon: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 14, vertical: 15),
                          child: Text('+91', style: AppText.title),
                        ),
                        prefixIconConstraints: BoxConstraints(minWidth: 0),
                        hintText: '90000 00000',
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              FadeSlideIn(
                delay: const Duration(milliseconds: 320),
                child: PrimaryButton(
                  label: 'Continue',
                  loading: _loading,
                  onPressed: _continue,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Flat solid-teal rounded-square logo mark. No gradient, no glow.
class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(Icons.electric_bike_rounded,
          color: Colors.white, size: 40),
    );
  }
}
