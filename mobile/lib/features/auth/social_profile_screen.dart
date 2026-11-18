import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import 'auth_layout.dart';
import 'parent_role.dart';
import 'registration_profile_form.dart';
import 'social_provider_icon.dart';

class SocialProfileScreen extends StatefulWidget {
  const SocialProfileScreen({
    super.key,
    required this.provider,
    required this.account,
  });
  final SocialProvider provider;
  final Map<String, dynamic> account;
  @override
  State<SocialProfileScreen> createState() => _SocialProfileScreenState();
}

class _SocialProfileScreenState extends State<SocialProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _mascot = AuthMascotController();
  late final _name = TextEditingController(
    text: widget.account['displayName'] as String? ?? '',
  );
  ParentRole? _role;
  bool _accepted = false, _attempted = false;
  @override
  void dispose() {
    _name.dispose();
    _mascot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
    title: 'Thông tin của bạn',
    subtitle: '',
    onBack: () => Navigator.pop(context),
    mascot: _mascot,
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RegistrationProfileForm(
            name: _name,
            role: _role,
            accepted: _accepted,
            enabled: true,
            showConsentError: _attempted,
            onRole: (v) => setState(() => _role = v),
            onAccepted: (v) => setState(() => _accepted = v),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              setState(() => _attempted = true);
              if (!(_form.currentState?.validate() ?? false) || !_accepted) {
                _mascot.showError();
                return;
              }
              Navigator.pop(
                context,
                SocialRegistrationConsent(
                  relationship: _role!.registrationValue,
                  displayName: _name.text.trim(),
                ),
              );
            },
            child: const Text('Hoàn tất đăng ký'),
          ),
        ],
      ),
    ),
  );
}
