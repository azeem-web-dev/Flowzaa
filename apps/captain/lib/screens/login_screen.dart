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
  final _phoneController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String get _phoneNumber => '+91${_phoneController.text.trim()}';

  Future<void> _continue() async {
    final digits = _phoneController.text.trim();
    if (digits.length != 10) {
      _snack('Enter a valid 10-digit phone number');
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
          '9000000002 (OTP 123456).');
    });
    try {
      await auth.sendOtp(
        phoneNumber: _phoneNumber,
        onCodeSent: (verificationId) {
          handled = true;
          if (!mounted) return;
          setState(() => _loading = false);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OtpScreen(
                verificationId: verificationId,
                phoneNumber: _phoneNumber,
              ),
            ),
          );
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
      _snack('$e');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Row(
                children: [
                  Container(
                    height: 56,
                    width: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.two_wheeler_rounded,
                        color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Flowzaa', style: AppText.display),
                      Text('Captain', style: AppText.bodySoft),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text('Drive with Flowzaa', style: AppText.h1),
              const SizedBox(height: 6),
              const Text(
                'Earn on every trip. Riders pay you directly — '
                'Flowzaa takes 0% commission.',
                style: AppText.bodySoft,
              ),
              const SizedBox(height: 28),
              const Text('PHONE NUMBER', style: AppText.label),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    const Text('+91', style: AppText.title),
                    const SizedBox(width: 10),
                    Container(width: 1, height: 24, color: AppColors.line),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        style: AppText.title,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                          hintText: '90000 00000',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Continue',
                loading: _loading,
                onPressed: _continue,
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
