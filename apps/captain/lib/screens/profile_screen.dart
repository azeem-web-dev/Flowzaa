import 'package:flowzaa_shared/flowzaa_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../widgets/vehicle_type_selector.dart';
import 'earnings_screen.dart';

/// The captain's own profile: view stats, edit details, sign out.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _vehicleNumber = TextEditingController();
  final _vehicleModel = TextEditingController();
  final _license = TextEditingController();
  final _upi = TextEditingController();

  VehicleType _vehicleType = VehicleType.bike;
  bool _seeded = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _vehicleNumber.dispose();
    _vehicleModel.dispose();
    _license.dispose();
    _upi.dispose();
    super.dispose();
  }

  void _seed(Captain captain) {
    if (_seeded) return;
    _seeded = true;
    _name.text = captain.name;
    _vehicleNumber.text = captain.vehicleNumber;
    _vehicleModel.text = captain.vehicleModel;
    _license.text = captain.licenseNumber;
    _upi.text = captain.upiId ?? '';
    _vehicleType = captain.vehicleType;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(uidProvider);
    if (uid == null) return;
    setState(() => _saving = true);
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
      if (mounted) _snack('Profile updated');
    } catch (e) {
      if (mounted) _snack('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
            "You'll stop receiving ride requests until you sign in again."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await ref.read(authServiceProvider).signOut();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showAbout() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('About Flowzaa'),
        content: const Text(
          'Flowzaa takes 0% commission. Every rupee a rider pays goes '
          'straight to you — collected in cash or via your own UPI QR. '
          'No weekly cuts, no hidden fees.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final captainAsync = ref.watch(captainProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: AppColors.scaffold,
        elevation: 0,
      ),
      body: captainAsync.when(
        loading: () =>
            const Center(child: VehicleLoaderSmall(label: 'Loading…')),
        error: (e, _) => Center(child: Text('$e', style: AppText.bodySoft)),
        data: (captain) {
          if (captain == null) {
            return const Center(child: VehicleLoaderSmall(label: 'Loading…'));
          }
          _seed(captain);
          return _body(captain);
        },
      ),
    );
  }

  Widget _body(Captain captain) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FadeSlideIn(child: _headerCard(captain)),
          const SizedBox(height: 20),
          const Text('Edit details', style: AppText.h2),
          const SizedBox(height: 14),
          _field(_name, 'Full name', Icons.person_outline,
              validator: _required),
          const SizedBox(height: 18),
          const Text('VEHICLE TYPE', style: AppText.label),
          const SizedBox(height: 10),
          VehicleTypeSelector(
            value: _vehicleType,
            onChanged: (type) => setState(() => _vehicleType = type),
          ),
          const SizedBox(height: 18),
          _field(_vehicleNumber, 'Vehicle number (e.g. KA01AB1234)',
              Icons.confirmation_number_outlined,
              validator: _required, capitalize: true),
          const SizedBox(height: 14),
          _field(_vehicleModel, 'Vehicle model (e.g. Honda Activa)',
              Icons.directions_car_outlined),
          const SizedBox(height: 14),
          _field(_license, 'Driving license number', Icons.badge_outlined,
              validator: _required, capitalize: true),
          const SizedBox(height: 14),
          _field(_upi, 'UPI ID (yourname@upi)',
              Icons.account_balance_wallet_outlined),
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'Save Changes',
            icon: Icons.check_rounded,
            loading: _saving,
            onPressed: _save,
          ),
          const SizedBox(height: 28),
          _tile(
            icon: Icons.account_balance_wallet_outlined,
            color: AppColors.primary,
            title: 'Earnings',
            subtitle: 'Today, this week and trip history',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EarningsScreen()),
            ),
          ),
          const SizedBox(height: 10),
          _tile(
            icon: Icons.info_outline_rounded,
            color: AppColors.info,
            title: 'About',
            subtitle: '0% commission — it\'s all yours',
            onTap: _showAbout,
          ),
          const SizedBox(height: 10),
          _tile(
            icon: Icons.logout_rounded,
            color: AppColors.danger,
            title: 'Sign out',
            subtitle: Fmt.phone(captain.phone),
            onTap: _signOut,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _headerCard(Captain captain) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.primary,
            child: Text(
              captain.name.isNotEmpty ? captain.name[0].toUpperCase() : 'C',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(captain.name, style: AppText.title),
                const SizedBox(height: 2),
                Text(Fmt.phone(captain.phone), style: AppText.bodySoft),
                const SizedBox(height: 6),
                Row(
                  children: [
                    RatingStars(value: captain.rating, size: 16),
                    const SizedBox(width: 8),
                    Text('${captain.totalRides} trips',
                        style: AppText.bodySoft),
                  ],
                ),
              ],
            ),
          ),
          VehicleIcon(type: captain.vehicleType, size: 44),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.title),
                    Text(subtitle, style: AppText.label),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.inkSoft),
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
