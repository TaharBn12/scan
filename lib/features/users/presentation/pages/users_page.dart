import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/security/session_controller.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/entities/app_user.dart';

/// Manage cashiers / managers. When multi-user mode is switched on, the app
/// asks "who is working?" at start-up and each user signs in with a PIN.
/// Cashiers can sell and look up customers; everything else is admin-only.
class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final _repo = UserRepository();
  List<AppUser> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await _repo.getUsers();
    if (!mounted) return;
    setState(() {
      _users = result.getOrElse((_) => []);
      _loading = false;
    });
    sessionController.refresh();
  }

  void _snack(String text, {Color? color}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), backgroundColor: color));
  }

  Future<void> _openForm({AppUser? existing}) async {
    final l10n = context.l10n;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final pinCtrl = TextEditingController();
    UserRole role = existing?.role ?? UserRole.cashier;
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? l10n.t('add_user') : l10n.t('edit_user')),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  autofocus: existing == null,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: l10n.t('user_name'),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l10n.t('required_field')
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: pinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: l10n.t('user_pin'),
                    helperText: existing == null ? null : l10n.t('optional'),
                    border: const OutlineInputBorder(),
                    counterText: '',
                  ),
                  validator: (v) {
                    final pin = (v ?? '').trim();
                    if (pin.isEmpty) {
                      return existing == null ? l10n.t('pin_too_short') : null;
                    }
                    if (pin.length < 4 || pin.length > 6) {
                      return l10n.t('pin_too_short');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                SegmentedButton<UserRole>(
                  segments: [
                    for (final r in UserRole.values)
                      ButtonSegment(
                        value: r,
                        icon: Icon(r == UserRole.admin
                            ? Icons.admin_panel_settings_outlined
                            : Icons.point_of_sale_outlined),
                        label: Text(l10n.t(r.labelKey)),
                      ),
                  ],
                  selected: {role},
                  onSelectionChanged: (s) =>
                      setDialogState(() => role = s.first),
                ),
                const SizedBox(height: 8),
                Text(l10n.t('admin_only_hint'),
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color)),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: Text(l10n.cancel)),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState?.validate() != true) return;
                final result = await _repo.saveUser(
                  id: existing?.id,
                  name: nameCtrl.text,
                  role: role,
                  pin: pinCtrl.text.trim().isEmpty ? null : pinCtrl.text.trim(),
                );
                if (!context.mounted) return;
                result.fold(
                  (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(l10n.t(f.message)),
                      backgroundColor: Colors.red)),
                  (_) => Navigator.pop(dialog, true),
                );
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted) {
      _snack(l10n.t('user_saved'), color: Colors.green);
      await _load();
    }
  }

  Future<void> _delete(AppUser u) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l10n.t('delete_user')),
        content: Text(l10n.t('delete_user_confirm', {'name': u.name})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: Text(l10n.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(d, true),
              child: Text(l10n.delete,
                  style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final result = await _repo.deleteUser(u.id);
    if (!mounted) return;
    result.fold(
      (f) => _snack(l10n.t(f.message), color: Colors.red),
      (_) => _load(),
    );
  }

  Future<void> _toggleMultiUser(bool enabled) async {
    final l10n = context.l10n;
    if (enabled && !_users.any((u) => u.isAdmin)) {
      _snack(l10n.t('cannot_delete_last_admin'), color: Colors.red);
      return;
    }
    await sessionController.setMultiUser(enabled);
    if (!mounted) return;
    setState(() {});
    if (enabled) {
      // Force the "who is working?" screen right away.
      await sessionController.lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final multiUser = sessionController.isMultiUser;
    final current = sessionController.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.users),
        leading: IconButton(
          icon: Icon(Icons.adaptive.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/settings'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(l10n.t('add_user')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                Card(
                  child: SwitchListTile(
                    secondary: const Icon(Icons.groups_outlined),
                    title: Text(l10n.t('multi_user')),
                    subtitle: Text(l10n.t('multi_user_hint')),
                    value: multiUser,
                    onChanged: _users.isEmpty ? null : _toggleMultiUser,
                  ),
                ),
                if (current != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.badge_outlined),
                      title: Text(l10n.t('current_user')),
                      subtitle: Text(
                          '${current.name} · ${l10n.t(current.role.labelKey)}'),
                      trailing: TextButton.icon(
                        onPressed: () => sessionController.lock(),
                        icon: const Icon(Icons.swap_horiz),
                        label: Text(l10n.t('switch_user')),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                if (_users.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.people_outline,
                            size: 64, color: theme.disabledColor),
                        const SizedBox(height: 12),
                        Text(l10n.t('no_users_hint'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: theme.disabledColor)),
                      ],
                    ),
                  )
                else
                  for (final u in _users)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: u.isAdmin
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.secondaryContainer,
                          child: Icon(
                            u.isAdmin
                                ? Icons.admin_panel_settings_outlined
                                : Icons.point_of_sale_outlined,
                            color: u.isAdmin
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                        title: Text(u.name,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(l10n.t(u.role.labelKey)),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') _openForm(existing: u);
                            if (v == 'delete') _delete(u);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.edit_outlined),
                                title: Text(l10n.edit),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.delete_outline,
                                    color: Colors.red),
                                title: Text(l10n.delete,
                                    style: const TextStyle(color: Colors.red)),
                              ),
                            ),
                          ],
                        ),
                        onTap: () => _openForm(existing: u),
                      ),
                    ),
              ],
            ),
    );
  }
}
