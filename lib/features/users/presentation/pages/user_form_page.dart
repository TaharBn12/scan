import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../users/domain/entities/app_user.dart';

/// Edit a shop member (cloud): name, role and whether they're active.
/// Pops with the edited map so the caller performs the cloud write.
/// Credentials are Firebase Auth's business — never edited from another
/// person's device.
class UserFormPage extends StatefulWidget {
  final String memberId;
  final Map<String, dynamic> memberMap;

  const UserFormPage({
    super.key,
    required this.memberId,
    required this.memberMap,
  });

  @override
  State<UserFormPage> createState() => _UserFormPageState();
}

class _UserFormPageState extends State<UserFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late UserRole _role;
  late bool _active;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
        text: (widget.memberMap['name'] as String?) ?? '');
    _role = UserRoleX.fromName(widget.memberMap['role'] as String?);
    _active = widget.memberMap['active'] != false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop({
      'name': _nameCtrl.text.trim(),
      'role': _role.name,
      'active': _active,
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final email = (widget.memberMap['email'] as String?) ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('edit_member'))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (email.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    Icon(Icons.alternate_email_rounded,
                        size: 18, color: context.mutedColor),
                    const SizedBox(width: 6),
                    Text(email,
                        style: TextStyle(color: context.mutedColor)),
                  ],
                ),
              ),
            TextFormField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.t('your_name'),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l10n.t('field_required')
                  : null,
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
            const SizedBox(height: 18),
            SwitchListTile(
              value: _active,
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.t('member_active')),
              subtitle: Text(l10n.t('member_active_hint')),
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _save,
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              icon: const Icon(Icons.check_rounded),
              label: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}
