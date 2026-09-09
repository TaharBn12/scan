import 'package:flutter/material.dart';

import '../../../../core/cloud/firebase_layer.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/security/auth_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../domain/entities/app_user.dart';

/// The admin opens teammate accounts himself: name + email + password +
/// role. The shop's sync code (LT-XXXX) is injected automatically — shown
/// read-only so nobody has to type it. The account works right away; the
/// teammate simply signs in on his own phone.
class CreateMemberPage extends StatefulWidget {
  final String shopId;
  const CreateMemberPage({super.key, required this.shopId});

  @override
  State<CreateMemberPage> createState() => _CreateMemberPageState();
}

class _CreateMemberPageState extends State<CreateMemberPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  UserRole _role = UserRole.cashier;
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final l10n = context.l10n;
    try {
      final uid = await FirebaseLayer.createAuthAccount(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
        displayName: _nameCtrl.text,
      );
      await FirebaseLayer.enrollMember(
        shopId: widget.shopId,
        uid: uid,
        name: _nameCtrl.text,
        email: _emailCtrl.text,
        role: switch (_role) {
          UserRole.admin => MemberRole.admin,
          UserRole.accountant => MemberRole.accountant,
          UserRole.stockkeeper => MemberRole.stockkeeper,
          UserRole.deliverer => MemberRole.deliverer,
          UserRole.cashier => MemberRole.cashier,
        },
      );
      if (!mounted) return;
      showAppSnack(
        context,
        '${l10n.t('member_created_toast')} — ${_nameCtrl.text.trim()}',
        icon: Icons.check_circle_outline_rounded,
        color: AppTheme.success,
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showAppSnack(context, l10n.t(AuthErrorKeys.from(e)),
          icon: Icons.error_outline_rounded, color: AppTheme.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final code = FirebaseLayer.shopCodeOf(widget.shopId);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('add_member'))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Read-only sync code: the account belongs to *this* shop.
            AppCard(
              color:
                  context.scheme.primaryContainer.withValues(alpha: 0.4),
              child: Row(
                children: [
                  Icon(Icons.key_rounded, color: context.scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.t('shop_code_label'),
                            style: TextStyle(
                                fontSize: 12, color: context.mutedColor)),
                        Text(code,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5)),
                      ],
                    ),
                  ),
                  Icon(Icons.lock_outline_rounded,
                      size: 17, color: context.mutedColor),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 16),
              child: Text(
                l10n.t('shop_code_readonly_hint'),
                style: TextStyle(fontSize: 11.5, color: context.mutedColor),
              ),
            ),
            TextFormField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.t('your_name'),
                prefixIcon: const Icon(Icons.person_outline_rounded),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l10n.t('field_required')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.t('member_email_label'),
                prefixIcon: const Icon(Icons.alternate_email_rounded),
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                final value = (v ?? '').trim();
                if (value.isEmpty) return l10n.t('field_required');
                if (!AuthHelper.isValidEmail(value)) {
                  return l10n.t('auth_error_invalid_email');
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.t('member_password_label'),
                helperText: l10n.t('password_min_hint'),
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return l10n.t('field_required');
                if (v.length < 6) return l10n.t('password_min_hint');
                return null;
              },
            ),
            const SizedBox(height: 18),
            Text(l10n.t('member_role_title'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SegmentedButton<UserRole>(
              segments: [
                ButtonSegment(
                    value: UserRole.admin,
                    label: Text(l10n.t('role_admin')),
                    icon:
                        const Icon(Icons.admin_panel_settings_outlined)),
                ButtonSegment(
                    value: UserRole.cashier,
                    label: Text(l10n.t('role_cashier')),
                    icon: const Icon(Icons.point_of_sale_rounded)),
                ButtonSegment(
                    value: UserRole.accountant,
                    label: Text(l10n.t('role_accountant')),
                    icon: const Icon(Icons.receipt_long_outlined)),
                ButtonSegment(
                    value: UserRole.deliverer,
                    label: Text(l10n.t('role_deliverer')),
                    icon: const Icon(Icons.delivery_dining_rounded)),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),
            const SizedBox(height: 6),
            Text(l10n.t(_role.descriptionKey),
                style: TextStyle(fontSize: 12, color: context.mutedColor)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    context.scheme.tertiaryContainer.withValues(alpha: 0.35),
                borderRadius: AppTheme.brMd,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 17, color: context.scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(l10n.t('add_member_subtitle'),
                        style: const TextStyle(fontSize: 12.5)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _create,
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15)),
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.person_add_alt_1_rounded),
                label: Text(l10n.t('create_account_cta')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
