import 'package:flutter/material.dart';

import '../cloud/cloud_database.dart';
import '../l10n/app_localizations.dart';
import 'session_controller.dart';

/// Gates sensitive actions (big discounts, refunds, stock corrections...)
/// behind a manager.
///
/// Cloud mode: memberships carry the role, and secrets live in Firebase
/// Auth — so approval means "the signed-in person is an admin". A cashier
/// asking for one gets a clear explanation and the operation is refused;
/// the manager signs in on the device and retries. Works offline, never
/// dead-ends, and cannot be bypassed without admin credentials.
class ManagerApproval {
  ManagerApproval._();

  static const _discountLimitKey = 'discount_limit_percent';

  /// A discount beyond this percentage of the subtotal needs a manager.
  static double get discountLimitPercent =>
      (CloudDatabase.settingsBox.get(_discountLimitKey) as num?)?.toDouble() ??
      10;

  static Future<void> setDiscountLimitPercent(double value) =>
      CloudDatabase.settingsBox.put(_discountLimitKey, value);

  /// Approvals only matter when the person holding the phone is *not* a
  /// manager. Single-owner shops never see the extra dialog.
  static bool get isRequired => !sessionController.isAdmin;

  /// Legacy quick-PIN check — cloud members carry no PINs, so this only
  /// stays for the legacy code paths and always reports no match.
  static bool verifyPin(String pin) => false;

  /// Asks for a manager's approval; resolves true when granted. In cloud
  /// mode a non-admin can never self-approve: the dialog explains that an
  /// admin must sign in on the device.
  static Future<bool> request(
    BuildContext context, {
    required String reasonKey,
    Map<String, Object?> reasonArgs = const {},
  }) async {
    if (!isRequired) return true;

    final l10n = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.admin_panel_settings_outlined),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.t('manager_approval_title'))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (reasonKey.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(l10n.t(reasonKey, reasonArgs)),
              ),
            Text(l10n.t('manager_approval_admin_only')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
    return result == true;
  }
}
