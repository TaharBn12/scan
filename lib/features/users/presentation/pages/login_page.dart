import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../shop/data/repositories/shop_repository_impl.dart';

/// Sign-in screen for shops that run with accounts.
///
/// Two ways in, side by side: the full account (identifier + password) for
/// managers and accountants, and the quick PIN pad for cashiers who sign in
/// twenty times a day.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final failure = await sessionController.signInWithPassword(
      _emailController.text,
      _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (failure == null) {
      _passwordController.clear();
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/menu');
      }
      return;
    }
    HapticFeedback.heavyImpact();
    setState(() => _error = failure);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shop = ShopRepositoryImpl.current();
    final hasPinAccounts = sessionController.hasPinAccounts;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: themeController.accent.gradient),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ---- shop identity ----
                      Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 1.5),
                        ),
                        child: const Icon(Icons.storefront_rounded,
                            color: Colors.white, size: 34),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        shop.name.isEmpty ? l10n.appTitle : shop.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.t('sign_in_subtitle'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ---- credentials card ----
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                          boxShadow: AppTheme.shadow(
                              Theme.of(context).brightness,
                              strong: true),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(l10n.t('sign_in'),
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autocorrect: false,
                                decoration: InputDecoration(
                                  labelText: l10n.t('email_or_username'),
                                  prefixIcon: const Icon(
                                      Icons.alternate_email_rounded, size: 19),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? l10n.t('required_field')
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscure,
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(
                                  labelText: l10n.t('password'),
                                  prefixIcon:
                                      const Icon(Icons.lock_outline, size: 19),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                        _obscure
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        size: 19),
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                  ),
                                ),
                                validator: (v) => (v == null || v.isEmpty)
                                    ? l10n.t('required_field')
                                    : null,
                                onFieldSubmitted: (_) => _submit(),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.danger
                                        .withValues(alpha: 0.10),
                                    borderRadius: AppTheme.brSm,
                                    border: Border.all(
                                        color: AppTheme.danger
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline,
                                          color: AppTheme.danger, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(l10n.t(_error!),
                                            style: const TextStyle(
                                                color: AppTheme.danger,
                                                fontSize: 12.5)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              ElevatedButton.icon(
                                onPressed: _busy ? null : _submit,
                                icon: _busy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Icon(Icons.login_rounded, size: 19),
                                label: Text(l10n.t('sign_in')),
                              ),
                              if (hasPinAccounts) ...[
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: () => context.push('/lock'),
                                  icon: const Icon(Icons.dialpad_rounded,
                                      size: 19),
                                  label: Text(l10n.t('sign_in_with_pin')),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        l10n.t('offline_mode'),
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
