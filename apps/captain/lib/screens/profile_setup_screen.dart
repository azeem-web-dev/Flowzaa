import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../widgets/vehicle_type_selector.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() =>
      _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _vehicleNumber = TextEditingController();
  final _vehicleModel = TextEditingController();
  final _license = TextEditingController();
  final _upi = TextEditingController();

  VehicleType _vehicleType = VehicleType.bike;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _vehicleNumber.dispose();
    _vehicleModel.dispose();
    _license.dispose();
    _upi.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(uidProvider);
    if (uid == null) return;
    setState(() => _loading = true);
    try {
      await ref.read(captainServiceProvider).saveProfile(
            uid: uid,
            name: _name.text.trim(),
            vehicleType: _vehicleType,
            vehicleNumber: _vehicleNumber.text.trim(),
            vehicleModel: _vehicleModel.text.trim(),
            licenseNumber: _license.text.trim(),
            upiId: _upi.text.trim().isEmpty ? null : _upi.text.trim(),
          );
      // captainProvider stream will emit a complete profile → HomeScreen.
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        title: const Text('Set up your profile'),
        backgroundColor: AppColors.scaffold,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const FadeSlideIn(
                child: Text('Your details', style: AppText.h2),
              ),
              const SizedBox(height: 16),
              FadeSlideIn(
                delay: const Duration(milliseconds: 50),
                child: _field(_name, 'Full name', Icons.person_outline,
                    validator: _required),
              ),
              const SizedBox(height: 20),
              const FadeSlideIn(
                delay: Duration(milliseconds: 100),
                child: Text('VEHICLE TYPE', style: AppText.label),
              ),
              const SizedBox(height: 10),
              FadeSlideIn(
                delay: const Duration(milliseconds: 150),
                child: VehicleTypeSelector(
                  value: _vehicleType,
                  onChanged: (type) => setState(() => _vehicleType = type),
                ),
              ),
              const SizedBox(height: 20),
              FadeSlideIn(
                delay: const Duration(milliseconds: 200),
                child: _field(_vehicleNumber,
                    'Vehicle number (e.g. KA01AB1234)',
                    Icons.confirmation_number_outlined,
                    validator: _required,
                    capitalize: true),
              ),
              const SizedBox(height: 16),
              FadeSlideIn(
                delay: const Duration(milliseconds: 250),
                child: _field(_vehicleModel,
                    'Vehicle model (e.g. Honda Activa)',
                    Icons.directions_car_outlined),
              ),
              const SizedBox(height: 16),
              FadeSlideIn(
                delay: const Duration(milliseconds: 300),
                child: _field(_license, 'Driving license number',
                    Icons.badge_outlined,
                    validator: _required, capitalize: true),
              ),
              const SizedBox(height: 24),
              FadeSlideIn(
                delay: const Duration(milliseconds: 350),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.qr_code_2_rounded,
                              color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Your UPI ID — riders pay you directly, '
                              'Flowzaa takes 0%',
                              style: AppText.label
                                  .copyWith(color: AppColors.ink),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _field(_upi, 'yourname@upi',
                          Icons.account_balance_wallet_outlined),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              FadeSlideIn(
                delay: const Duration(milliseconds: 400),
                child: PrimaryButton(
                  label: 'Save & Start Driving',
                  loading: _loading,
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  Widget _field(
    TextEditingController controller,
    String hint,
    IconData icon, {
    String? Function(String?)? validator,
    bool capitalize = false,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      textCapitalization:
          capitalize ? TextCapitalization.characters : TextCapitalization.words,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
      ),
    );
  }
}
