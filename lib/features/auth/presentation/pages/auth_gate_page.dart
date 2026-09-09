import 'package:flutter/material.dart';

import '../../../../core/cloud/cloud_auth_controller.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/security/auth_helper.dart';

/// Brand header shared by the auth screens.
class _BrandHeader extends StatelessWidget {
  final String subtitle;
  const _BrandHeader({required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [
                context.scheme.primary,
                context.scheme.primary.withOpacity(0.65),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: context.scheme.primary.withOpacity(0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.point_of_sale_rounded,
              color: Colors.white, size: 42),
        ),
        const SizedBox(height: 14),
        Text(l10n.appTitle,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedColor, fontSize: 13)),
      ],
    );
  }
}

/// Shown on every app start while the cloud session is being resolved.
class SplashPage extends StatelessWidget {
  final CloudAuthController controller;
  const SplashPage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final missing = controller.state == CloudAuthState.configMissing;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: _BrandHeader(subtitle: l10n.t('splash_tagline')),
              ),
              const SizedBox(height: 40),
              if (missing) ...[
                Icon(Icons.cloud_off_rounded,
                    color: context.scheme.error, size: 48),
                const SizedBox(height: 12),
                Text(l10n.t('firebase_missing_title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(l10n.t('firebase_missing_body'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.mutedColor, height: 1.5)),
              ] else ...[
                const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(strokeWidth: 2.4)),
                const SizedBox(height: 14),
                Text(l10n.t('splash_loading'),
                    style: TextStyle(color: context.mutedColor, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Mandatory sign-in / registration. The router never lets an anonymous
/// visitor past this page.
class CloudLoginPage extends StatefulWidget {
  final CloudAuthController controller;
  const CloudLoginPage({super.key, required this.controller});

  @override
  State<CloudLoginPage> createState() => _CloudLoginPageState();
}

class _CloudLoginPageState extends State<CloudLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _shopNameCtrl = TextEditingController();
  final _shopCodeCtrl = TextEditingController();

  bool _register = false;
  bool _loading = false;
  bool _obscure = true;
  String? _errorKey;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _shopNameCtrl.dispose();
    _shopCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorKey = null;
    });
    String? failure;
    if (_register) {
      failure = await widget.controller.register(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
        displayName: _nameCtrl.text,
        shopName: _shopNameCtrl.text,
        shopCode:
            _shopCodeCtrl.text.trim().isEmpty ? null : _shopCodeCtrl.text,
      );
    } else {
      failure =
          await widget.controller.signIn(_emailCtrl.text, _passwordCtrl.text);
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _errorKey = failure;
    });
    // Success: the controller flips state and the router navigates away.
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  _BrandHeader(
                      subtitle: _register
                          ? l10n.t('register_subtitle')
                          : l10n.t('login_subtitle')),
                  const SizedBox(height: 28),

                  // Mode toggle
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                          value: false,
                          label: Text(l10n.t('login_tab')),
                          icon: const Icon(Icons.login_rounded)),
                      ButtonSegment(
                          value: true,
                          label: Text(l10n.t('register_tab')),
                          icon: const Icon(Icons.person_add_alt_rounded)),
                    ],
                    selected: {_register},
                    onSelectionChanged: (s) =>
                        setState(() => _register = s.first),
                  ),
                  const SizedBox(height: 22),

                  if (_register) ...[
                    TextFormField(
                      controller: _nameCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.t('your_name'),
                        prefixIcon: const Icon(Icons.badge_outlined),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? l10n.t('field_required')
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _shopNameCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.t('shop_name_label'),
                        prefixIcon: const Icon(Icons.storefront_outlined),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => _shopCodeCtrl.text.trim().isEmpty &&
                              (v == null || v.trim().isEmpty)
                          ? l10n.t('field_required')
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _shopCodeCtrl,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: l10n.t('shop_code_optional'),
                        helperText: l10n.t('shop_code_hint'),
                        prefixIcon: const Icon(Icons.key_rounded),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l10n.t('email_label'),
                      prefixIcon: const Icon(Icons.alternate_email_rounded),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => !AuthHelper.isValidEmail((v ?? '').trim())
                        ? l10n.t('auth_error_invalid_email')
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: l10n.t('password_label'),
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return l10n.t('field_required');
                      if (_register && v.length < 6) {
                        return l10n.t('auth_error_weak_password');
                      }
                      return null;
                    },
                  ),

                  if (_errorKey != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.scheme.errorContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded,
                              color: context.scheme.error),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(l10n.t(_errorKey!),
                                  style:
                                      TextStyle(color: context.scheme.error))),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),

                  FilledButton.icon(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15)),
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Icon(_register
                            ? Icons.person_add_alt_rounded
                            : Icons.login_rounded),
                    label: Text(
                        _register ? l10n.t('create_account') : l10n.t('sign_in'),
                        style: const TextStyle(fontSize: 15)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Signed in, but the account awaits the shop admin's approval.
class PendingApprovalPage extends StatelessWidget {
  final CloudAuthController controller;
  const PendingApprovalPage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_top_rounded,
                  size: 72, color: context.scheme.primary),
              const SizedBox(height: 16),
              Text(l10n.t('pending_title'),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(l10n.t('pending_body'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.mutedColor, height: 1.5)),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: () => controller.signOut(),
                icon: const Icon(Icons.logout_rounded),
                label: Text(l10n.t('sign_out')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
