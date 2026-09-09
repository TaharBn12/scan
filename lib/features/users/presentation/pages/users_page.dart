import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/cloud/cloud_auth_controller.dart';
import '../../../../core/cloud/cloud_database.dart';
import '../../../../core/cloud/firebase_layer.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ui_kit.dart';
import '../../../delivery/presentation/widgets/courier_earnings_sheet.dart';
import 'create_member_page.dart';
import 'user_form_page.dart';

/// Manage the shop's team, cloud side: pending join requests, roles,
/// activate/deactivate. Data lives at /shops/{shopId}/members and updates
/// live on every admin device.
class UsersPage extends StatefulWidget {
  final CloudAuthController controller;
  const UsersPage({super.key, required this.controller});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  String get _shopId => widget.controller.shopId ?? '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final code = FirebaseLayer.shopCodeOf(_shopId);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('cloud_users_title')),
        actions: [
          IconButton(
            tooltip: l10n.t('add_member'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CreateMemberPage(shopId: _shopId))),
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
          IconButton(
            tooltip: l10n.t('shop_code_label'),
            onPressed: () => _showShopCode(code),
            icon: const Icon(Icons.key_rounded),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: CloudDatabase.usersBox,
        builder: (context, _) {
          final box = CloudDatabase.usersBox;
          final members = <MapEntry<String, Map<String, dynamic>>>[
            for (final uid in box.keys)
              MapEntry(uid, Map<String, dynamic>.from(box.get(uid) ?? const {})),
          ]..sort((a, b) => (a.value['name'] as String? ?? '')
              .compareTo(b.value['name'] as String? ?? ''));

          if (members.isEmpty) {
            return EmptyState(
              icon: Icons.group_outlined,
              title: l10n.t('no_members_hint'),
              message: l10n.t('shop_code_hint'),
            );
          }

          final pending =
              members.where((m) => m.value['active'] == false).toList();
          final active =
              members.where((m) => m.value['active'] != false).toList();
          final myUid = widget.controller.profile?.uid;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              // Shop join code card
              AppCard(
                color: context.scheme.primaryContainer.withOpacity(0.4),
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
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.t('copy'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        showAppSnack(context, l10n.t('copied'));
                      },
                      icon: const Icon(Icons.copy_rounded, size: 20),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (pending.isNotEmpty) ...[
                SectionHeader(title: l10n.t('members_pending')),
                for (final m in pending) _memberTile(m, isPending: true),
                const SizedBox(height: 14),
              ],

              SectionHeader(title: l10n.t('cloud_users_title')),
              for (final m in active) _memberTile(m, myUid: myUid),
            ],
          );
        },
      ),
    );
  }

  void _showShopCode(String code) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.t('shop_code_label')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(code,
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2)),
            const SizedBox(height: 12),
            Text(l10n.t('shop_code_hint'),
                textAlign: TextAlign.center,
                style: TextStyle(color: context.mutedColor, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: Text(l10n.close)),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(dialog);
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: Text(l10n.t('copy')),
          ),
        ],
      ),
    );
  }

  Widget _memberTile(MapEntry<String, Map<String, dynamic>> entry,
      {bool isPending = false, String? myUid}) {
    final l10n = context.l10n;
    final m = entry.value;
    final name = (m['name'] as String?)?.isNotEmpty == true
        ? m['name'] as String
        : (m['email'] as String? ?? '—');
    final roleName = m['role'] as String? ?? 'cashier';
    final email = m['email'] as String? ?? '';
    final isMe = myUid == entry.key;
    final isBlocked = m['blocked'] == true;
    final isDelivererOnDuty =
        roleName == 'deliverer' && m['onDuty'] == true;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isPending
                ? context.scheme.errorContainer
                : context.scheme.primaryContainer,
            child: Icon(
                isPending
                    ? Icons.hourglass_top_rounded
                    : roleName == 'admin'
                        ? Icons.admin_panel_settings_outlined
                        : Icons.person_outline_rounded,
                color: isPending
                    ? context.scheme.onErrorContainer
                    : context.scheme.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (email.isNotEmpty)
                  Text(email,
                      style:
                          TextStyle(fontSize: 12, color: context.mutedColor)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppBadge(
                text: isBlocked
                    ? l10n.t('member_blocked')
                    : l10n.t('role_$roleName'),
                color: isBlocked
                    ? AppTheme.danger
                    : roleName == 'admin'
                        ? context.scheme.primary
                        : roleName == 'deliverer'
                            ? AppTheme.info
                            : context.mutedColor,
              ),
              if (isDelivererOnDuty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: AppBadge(
                    text: l10n.t('member_duty_on'),
                    color: AppTheme.success,
                    icon: Icons.circle,
                  ),
                ),
            ],
          ),
          if (!isMe && roleName == 'deliverer')
            IconButton(
              tooltip: l10n.t('courier_earnings'),
              onPressed: () => _showCourierEarnings(entry),
              icon: Icon(Icons.payments_outlined,
                  size: 20, color: AppTheme.success),
            ),
          if (!isMe) ...[
            IconButton(
              tooltip: l10n.edit,
              onPressed: () => _editMember(entry),
              icon: const Icon(Icons.edit_outlined, size: 20),
            ),
            IconButton(
              tooltip: isBlocked
                  ? l10n.t('unblock_member')
                  : l10n.t('block_member'),
              onPressed: () => _toggleBlock(entry),
              icon: Icon(
                  isBlocked
                      ? Icons.lock_open_rounded
                      : Icons.block_rounded,
                  size: 20,
                  color: isBlocked ? AppTheme.success : null),
            ),
            IconButton(
              tooltip: l10n.delete,
              onPressed: () => _removeMember(entry),
              icon: Icon(Icons.delete_outline_rounded,
                  size: 20, color: context.scheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _editMember(MapEntry<String, Map<String, dynamic>> entry) async {
    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => UserFormPage(memberId: entry.key, memberMap: entry.value),
      ),
    );
    if (updated == null || !mounted) return;
    await FirebaseLayer.saveMember(
      shopId: _shopId,
      uid: entry.key,
      name: updated['name'] as String,
      role: memberRoleFromName(updated['role'] as String?),
      active: updated['active'] as bool? ?? true,
    );
    if (mounted) showAppSnack(context, context.l10n.t('member_approved'));
  }

  Future<void> _showCourierEarnings(
      MapEntry<String, Map<String, dynamic>> entry) {
    final name = (entry.value['name'] as String?)?.isNotEmpty == true
        ? entry.value['name'] as String
        : entry.key;
    return showCourierEarningsSheet(
      context,
      uid: entry.key,
      name: name,
      settledBy: widget.controller.profile?.name ?? '',
    );
  }

  /// Admin blocks/unblocks an account: the blocked member's session watch
  /// kicks him out within a second, and he cannot sign back in until the
  /// admin unblocks him here.
  Future<void> _toggleBlock(MapEntry<String, Map<String, dynamic>> entry) async {
    final l10n = context.l10n;
    final nowBlocked = entry.value['blocked'] == true;
    await FirebaseLayer.setMemberBlocked(_shopId, entry.key, !nowBlocked);
    if (!mounted) return;
    showAppSnack(
      context,
      nowBlocked ? l10n.t('unblocked_toast') : l10n.t('blocked_toast'),
      icon: nowBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
      color: nowBlocked ? AppTheme.success : AppTheme.warning,
    );
  }

  Future<void> _removeMember(MapEntry<String, Map<String, dynamic>> entry) async {
    final l10n = context.l10n;
    final name = (entry.value['name'] as String?) ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        icon: Icon(Icons.person_remove_outlined, color: context.scheme.error),
        title: Text(l10n.t('member_remove_q')),
        content: Text(l10n.t('member_remove_body', {'name': name})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(l10n.cancel)),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await FirebaseLayer.removeMember(_shopId, entry.key);
    // The account itself stays in Firebase Auth; it's simply no longer a
    // member of this shop.
    if (mounted) showAppSnack(context, l10n.t('member_removed'));
  }
}
