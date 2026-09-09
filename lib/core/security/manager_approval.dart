import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/hive_database.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'pin_helper.dart';
import 'session_controller.dart';

/// Sensitive actions (big discounts, deleting a cart line, refunds, stock
/// corrections) can be gated behind a manager's approval. The idea: the
/// cashier keeps serving the customer, the manager comes over, types their
/// PIN right there on the same screen, and the action goes through — no
/// sign-out/sign-in dance, and the shop owner finds no surprises at night.
class ManagerApproval {
  ManagerApproval._();

  static const _discountLimitKey = 'discount_limit_percent';

  /// A discount beyond this percentage of the subtotal needs a manager.
  static double get discountLimitPercent =>
      (HiveDatabase.settingsBox.get(_discountLimitKey) as num?)?.toDouble() ??
      10;

  static Future<void> setDiscountLimitPercent(double value) =>
      HiveDatabase.settingsBox.put(_discountLimitKey, value);

  /// Approvals only matter when the person holding the phone is *not* a
  /// manager. Single-owner shops never see the extra dialog.
  static bool get isRequired => !sessionController.isAdmin;

  /// Some way for a manager to prove themselves exists on this device.
  static bool get _canVerify =>
      sessionController.isMultiUser || PinHelper.hasAppPin;

  /// Checks [pin] against every active admin account (multi-user mode) or
  /// the app PIN (single-owner shop with a lock PIN but staff around).
  static bool verifyPin(String pin) {
    if (sessionController.isMultiUser) {
      for (final raw in HiveDatabase.usersBox.values) {
        final map = Map<String, dynamic>.from(raw as Map);
        final isAdmin = map['role'] == 'admin';
        final active = map['active'] as bool? ?? true;
        final pinHash = map['pinHash'] as String? ?? '';
        final salt = map['salt'] as String? ?? '';
        if (isAdmin &&
            active &&
            pinHash.isNotEmpty &&
            PinHelper.verify(pin, salt, pinHash)) {
          return true;
        }
      }
      return false;
    }
    return PinHelper.verifyAppPin(pin);
  }

  /// Asks for a manager's approval; resolves true when granted.
  ///
  /// When no verification method is configured at all (fresh shop, no
  /// accounts, no lock PIN) it degrades to a plain "manager is present and
  /// agrees" confirmation so the till never dead-ends.
  static Future<bool> request(
    BuildContext context, {
    required String reasonKey,
    Map<String, Object?> reasonArgs = const {},
  }) async {
    if (!isRequired) return true;
    if (!_canVerify) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(context.l10n.t('manager_approval_title')),
          content: Text(context.l10n.t('manager_approval_fallback')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(context.l10n.t('manager_present')),
            ),
          ],
        ),
      );
      return ok == true;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => _ApprovalDialog(
        reasonKey: reasonKey,
        reasonArgs: reasonArgs,
      ),
    );
    return result == true;
  }
}

class _ApprovalDialog extends StatefulWidget {
  final String reasonKey;
  final Map<String, Object?> reasonArgs;

  const _ApprovalDialog({required this.reasonKey, required this.reasonArgs});

  @override
  State<_ApprovalDialog> createState() => _ApprovalDialogState();
}

class _ApprovalDialogState extends State<_ApprovalDialog> {
  final _pinController = TextEditingController();
  String? _error;
  int _attempts = 0;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = _pinController.text.trim();
    if (!PinHelper.isValidPin(pin)) {
      setState(() => _error = context.l10n.t('pin_too_short'));
      return;
    }
    if (ManagerApproval.verifyPin(pin)) {
      Navigator.pop(context, true);
      return;
    }
    _attempts++;
    _pinController.clear();
    setState(() => _error = context.l10n.t('wrong_manager_pin'));
    // Three failed attempts close the dialog: better to cancel the action
    // than to let someone brute-force a 4-digit code at the counter.
    if (_attempts >= 3) Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.admin_panel_settings_outlined,
                color: AppTheme.warning, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(l10n.t('manager_approval_title'))),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.t(widget.reasonKey, widget.reasonArgs),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l10n.t('manager_pin'),
              errorText: _error,
              counterText: '',
              prefixIcon: const Icon(Icons.lock_outline),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.t('approve')),
        ),
      ],
    );
  }
}
