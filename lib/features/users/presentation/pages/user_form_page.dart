import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/security/auth_helper.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/entities/app_user.dart';

/// Admin screen to create or edit a staff account: full name, login
/// identifier, password, role and an optional quick PIN for the till.
class UserFormPage extends StatefulWidget {
  final AppUser? existing;
  const UserFormPage({super.key, this.existing});

  @override
  State<UserFormPage> createState() => _UserFormPageState();
}

class _UserFormPageState extends State<UserFormPage> {
  final _repo = UserRepository();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _email =
      TextEditingController(text: widget.existing?.email ?? '');
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  final TextEditingController _pin = TextEditingController();

  late UserRole _role = widget.existing?.role ?? UserRole.cashier;
  late bool _active = widget.existing?.active ?? true;
  bool _obscure = true;
  bool _saving = false;

  bool get _isNew => widget.existing == null;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _saving = true);
    final result = await _repo.saveUser(
      id: widget.existing?.id,
      name: _name.text,
      email: _email.text,
      role: _role,
      password: _password.text.trim().isEmpty ? null : _password.text.trim(),
      pin: _pin.text.trim().isEmpty ? null : _pin.text.trim(),
      active: _active,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    result.fold<void>(
      (failure) => showAppSnack(context, l10n.t(failure.message),
          icon: Icons.error_outline),
      (_) {
        sessionController.refresh();
        showAppSnack(context, l10n.t('user_saved'),
            icon: Icons.check_circle_outline);
        context.pop(true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final strength = AuthHelper.strength(_password.text);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.adaptive.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(_isNew ? l10n.t('add_user') : l10n.t('edit_user')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            // ------------------------------------------------ identity
            SectionHeader(title: l10n.t('account_details')),
            AppCard(
              child: Column(
                children: [
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: l10n.t('user_name'),
                      prefixIcon: const Icon(Icons.badge_outlined, size: 19),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.t('required_field')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: l10n.t('email_or_username'),
                      helperText: l10n.t('email_hint'),
                      prefixIcon:
                          const Icon(Icons.alternate_email_rounded, size: 19),
                    ),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) {
                        // Only required when the account uses a password.
                        return _password.text.trim().isEmpty && !_isNew
                            ? null
                            : l10n.t('required_field');
                      }
                      return AuthHelper.isValidEmail(value)
                          ? null
                          : l10n.t('invalid_email');
                    },
                  ),
                ],
              ),
            ),

            // ---------------------------------------------------- role
            const SizedBox(height: 20),
            SectionHeader(title: l10n.t('role')),
            for (final role in UserRole.values)
              _RoleTile(
                role: role,
                selected: _role == role,
                onTap: () => setState(() => _role = role),
              ),

            // ------------------------------------------------ password
            const SizedBox(height: 20),
            SectionHeader(title: l10n.t('password')),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: _isNew
                          ? l10n.t('password')
                          : l10n.t('new_password_optional'),
                      prefixIcon: const Icon(Icons.lock_outline, size: 19),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 19),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) {
                        if (_isNew && _pin.text.trim().isEmpty) {
                          return l10n.t('password_or_pin_required');
                        }
                        return null;
                      }
                      return AuthHelper.isValidPassword(value)
                          ? null
                          : l10n.t('password_too_short');
                    },
                  ),
                  if (_password.text.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _StrengthBar(strength: strength),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirm,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: l10n.t('confirm_password'),
                        prefixIcon:
                            const Icon(Icons.lock_reset_outlined, size: 19),
                      ),
                      validator: (v) => (v ?? '') == _password.text
                          ? null
                          : l10n.t('passwords_dont_match'),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _pin,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: l10n.t('quick_pin_optional'),
                      helperText: l10n.t('quick_pin_hint'),
                      prefixIcon: const Icon(Icons.dialpad_rounded, size: 19),
                      counterText: '',
                    ),
                    validator: (v) {
                      final pin = (v ?? '').trim();
                      if (pin.isEmpty) return null;
                      return (pin.length < 4 || pin.length > 6)
                          ? l10n.t('pin_too_short')
                          : null;
                    },
                  ),
                ],
              ),
            ),

            // -------------------------------------------------- status
            const SizedBox(height: 20),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.t('account_active'),
                    style: const TextStyle(fontSize: 14)),
                subtitle: Text(l10n.t('account_active_hint'),
                    style: const TextStyle(fontSize: 11)),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(top: BorderSide(color: context.borderColor)),
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded, size: 19),
            label: Text(l10n.save),
          ),
        ),
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  final UserRole role;
  final bool selected;
  final VoidCallback onTap;

  const _RoleTile({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  static IconData iconFor(UserRole role) => switch (role) {
        UserRole.admin => Icons.admin_panel_settings_rounded,
        UserRole.accountant => Icons.calculate_rounded,
        UserRole.stockkeeper => Icons.inventory_rounded,
        UserRole.cashier => Icons.point_of_sale_rounded,
      };

  static Color colorFor(UserRole role) => switch (role) {
        UserRole.admin => const Color(0xFF7C3AED),
        UserRole.accountant => AppTheme.info,
        UserRole.stockkeeper => AppTheme.warning,
        UserRole.cashier => AppTheme.success,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = colorFor(role);
    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderColor: selected ? color : null,
      color: selected ? color.withValues(alpha: 0.08) : null,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(iconFor(role), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.t(role.labelKey),
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(l10n.t(role.descriptionKey),
                    style: TextStyle(fontSize: 11.5, color: context.mutedColor)),
              ],
            ),
          ),
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            color: selected ? color : context.mutedColor,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _StrengthBar extends StatelessWidget {
  final int strength;
  const _StrengthBar({required this.strength});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = [
      AppTheme.danger,
      AppTheme.warning,
      AppTheme.info,
      AppTheme.success,
    ];
    final labels = [
      'password_weak',
      'password_fair',
      'password_good',
      'password_strong',
    ];
    final index = strength.clamp(0, 3);
    return Row(
      children: [
        for (int i = 0; i < 3; i++) ...[
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: i < index
                    ? colors[index]
                    : context.borderColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          if (i < 2) const SizedBox(width: 5),
        ],
        const SizedBox(width: 10),
        Text(l10n.t(labels[index]),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors[index])),
      ],
    );
  }
}
