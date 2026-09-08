import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/security/session_controller.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/entities/app_user.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ui_kit.dart';

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
    final saved = await context.push<bool>('/users/form', extra: existing);
    if (saved == true && mounted) await _load();
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
                  style: const TextStyle(color: AppTheme.danger))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final result = await _repo.deleteUser(u.id);
    if (!mounted) return;
    result.fold(
      (f) => _snack(l10n.t(f.message), color: AppTheme.danger),
      (_) => _load(),
    );
  }

  Future<void> _toggleMultiUser(bool enabled) async {
    final l10n = context.l10n;
    if (enabled && !_users.any((u) => u.isAdmin && (u.hasPassword || u.hasPin))) {
      // Without a usable admin account the owner would lock themselves out.
      _snack(l10n.t('need_admin_account'), color: AppTheme.danger);
      return;
    }
    await sessionController.setMultiUser(enabled);
    if (!mounted) return;
    setState(() {});
    if (enabled) {
      // Force the sign-in screen right away.
      await sessionController.lock();
      if (mounted) context.go('/login');
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
                          backgroundColor: _RoleStyle.colorFor(u.role)
                              .withValues(alpha: 0.15),
                          child: Text(
                            u.initials,
                            style: TextStyle(
                                color: _RoleStyle.colorFor(u.role),
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(u.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                            ),
                            if (!u.active) ...[
                              const SizedBox(width: 6),
                              AppBadge(
                                  text: l10n.t('disabled'),
                                  color: AppTheme.danger),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${l10n.t(u.role.labelKey)}'
                              '${u.email.isEmpty ? '' : ' · ${u.email}'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                if (u.hasPassword)
                                  Padding(
                                    padding:
                                        const EdgeInsetsDirectional.only(end: 6),
                                    child: AppBadge(
                                        text: l10n.t('password'),
                                        color: _RoleStyle.colorFor(u.role),
                                        icon: Icons.lock_outline),
                                  ),
                                if (u.hasPin)
                                  AppBadge(
                                      text: l10n.t('user_pin'),
                                      color: AppTheme.info,
                                      icon: Icons.dialpad_rounded),
                              ],
                            ),
                          ],
                        ),
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
                                    color: AppTheme.danger),
                                title: Text(l10n.delete,
                                    style: const TextStyle(color: AppTheme.danger)),
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

/// Colour per role, shared by the avatar and the badges.
class _RoleStyle {
  const _RoleStyle._();

  static Color colorFor(UserRole role) => switch (role) {
        UserRole.admin => const Color(0xFF7C3AED),
        UserRole.accountant => AppTheme.info,
        UserRole.stockkeeper => AppTheme.warning,
        UserRole.cashier => AppTheme.success,
      };
}
