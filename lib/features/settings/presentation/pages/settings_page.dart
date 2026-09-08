import 'dart:convert';
import 'dart:io';

import 'package:app_settings/app_settings.dart' as device_settings;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../core/data/hive_database.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/security/pin_helper.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/settings/app_settings_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/utils/backup_helper.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../customers/presentation/bloc/customer_bloc.dart';
import '../../../expenses/presentation/bloc/expense_bloc.dart';
import '../../../inventory/presentation/bloc/inventory_bloc.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../../sales/presentation/bloc/sale_bloc.dart';
import '../../../shop/presentation/bloc/shop_bloc.dart';
import '../bloc/printer_bloc.dart';
import '../bloc/printer_event.dart';
import '../bloc/printer_state.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _appVersion = '3.0.0';

  final TextEditingController _currencyController = TextEditingController();
  bool _backingUp = false;

  @override
  void initState() {
    super.initState();
    context.read<PrinterBloc>().add(InitPrinterEvent());
    _currencyController.text = appSettings.value.currencySymbol;
  }

  @override
  void dispose() {
    _currencyController.dispose();
    super.dispose();
  }

  void _snack(String text, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), backgroundColor: color));
  }

  String _shopName() {
    final s = context.read<ShopBloc>().state;
    return s is ShopLoaded && s.shop.name.isNotEmpty ? s.shop.name : '';
  }

  void _reloadAll() {
    context.read<ProductBloc>().add(LoadProducts());
    context.read<SaleBloc>().add(LoadSales());
    context.read<CustomerBloc>().add(LoadCustomers());
    context.read<ShopBloc>().add(LoadShopEvent());
    context.read<ExpenseBloc>().add(LoadExpenses());
    context.read<InventoryBloc>().add(LoadInventory());
  }

  // ------------------------------------------------------------ backups

  Future<void> _exportBackup() async {
    final l10n = context.l10n;
    setState(() => _backingUp = true);
    try {
      final file = await BackupHelper.exportAndShare(subject: l10n.appTitle);
      _snack(l10n.t('backup_saved', {'path': file.path.split('/').last}),
          color: AppTheme.success);
    } catch (e) {
      _snack(l10n.t('export_failed', {'error': e}), color: AppTheme.danger);
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  Future<void> _copyBackupToClipboard() async {
    final l10n = context.l10n;
    await Clipboard.setData(ClipboardData(text: BackupHelper.exportAsJson()));
    _snack(l10n.t('backup_copied'), color: AppTheme.success);
  }

  Future<void> _restore(Future<BackupImportSummary> Function() run) async {
    final l10n = context.l10n;
    try {
      final summary = await run();
      if (!mounted) return;
      _reloadAll();
      _snack(
          l10n.t('imported_summary', {
            'products': summary.productsImported,
            'sales': summary.salesImported,
            'customers': summary.customersImported,
          }),
          color: AppTheme.success);
    } catch (_) {
      _snack(l10n.t('import_failed'), color: AppTheme.danger);
    }
  }

  Future<bool> _confirmRestore() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('import_backup')),
        content: Text(l10n.t('restore_confirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.t('restore'))),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final picked = result.files.first;
    if (!await _confirmRestore()) return;
    await _restore(() async {
      if (picked.bytes != null) {
        return BackupHelper.importFromJson(utf8.decode(picked.bytes!));
      }
      if (picked.path != null) {
        return BackupHelper.importFromFile(File(picked.path!));
      }
      throw const FormatException('empty');
    });
  }

  Future<void> _importFromText() async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    final clipboard = await Clipboard.getData('text/plain');
    if (clipboard?.text != null && clipboard!.text!.trim().startsWith('{')) {
      controller.text = clipboard.text!;
    }
    if (!mounted) return;
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('import_title')),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: 8,
            decoration: InputDecoration(hintText: l10n.t('import_hint')),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: Text(l10n.t('restore'))),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty || !mounted) return;
    await _restore(() => BackupHelper.importFromJson(text));
  }

  Future<void> _showLocalBackups() async {
    final l10n = context.l10n;
    final files = await BackupHelper.listBackups();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: files.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(32),
                child: Text(l10n.t('no_backups_yet'),
                    textAlign: TextAlign.center),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final f in files)
                    ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(f.path.split('/').last),
                      subtitle: Text(
                          '${(f.lengthSync() / 1024).toStringAsFixed(1)} KB'),
                      onTap: () async {
                        Navigator.pop(sheet);
                        if (!await _confirmRestore()) return;
                        await _restore(() => BackupHelper.importFromFile(f));
                      },
                    ),
                ],
              ),
      ),
    );
  }

  // ----------------------------------------------------------------- PIN

  Future<String?> _askPin(String title, {String? hint}) async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    String? error;
    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: hint ?? l10n.t('enter_pin'),
              errorText: error,
              counterText: '',
            ),
            onSubmitted: (_) {
              if (!PinHelper.isValidPin(controller.text)) {
                setLocal(() => error = l10n.t('pin_too_short'));
                return;
              }
              Navigator.pop(ctx, controller.text);
            },
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            FilledButton(
              onPressed: () {
                if (!PinHelper.isValidPin(controller.text)) {
                  setLocal(() => error = l10n.t('pin_too_short'));
                  return;
                }
                Navigator.pop(ctx, controller.text);
              },
              child: Text(l10n.ok),
            ),
          ],
        ),
      ),
    );
    return pin;
  }

  Future<bool> _verifyCurrentPin() async {
    final l10n = context.l10n;
    if (!PinHelper.hasAppPin) return true;
    final current = await _askPin(l10n.t('current_pin'));
    if (current == null) return false;
    if (!PinHelper.verifyAppPin(current)) {
      _snack(l10n.t('wrong_pin'), color: AppTheme.danger);
      return false;
    }
    return true;
  }

  Future<void> _setOrChangePin() async {
    final l10n = context.l10n;
    if (!await _verifyCurrentPin()) return;
    if (!mounted) return;
    final pin = await _askPin(l10n.t('set_pin'), hint: l10n.t('enter_new_pin'));
    if (pin == null || !mounted) return;
    final confirm = await _askPin(l10n.t('confirm_pin'));
    if (confirm == null || !mounted) return;
    if (pin != confirm) {
      _snack(l10n.t('pin_mismatch'), color: AppTheme.danger);
      return;
    }
    await PinHelper.setAppPin(pin);
    await appSettings.setPinEnabled(true);
    sessionController.refresh();
    if (!mounted) return;
    setState(() {});
    _snack(l10n.t('pin_set'), color: AppTheme.success);
  }

  Future<void> _removePin() async {
    final l10n = context.l10n;
    if (!await _verifyCurrentPin()) return;
    await PinHelper.clearAppPin();
    await appSettings.setPinEnabled(false);
    sessionController.refresh();
    if (!mounted) return;
    setState(() {});
    _snack(l10n.t('pin_removed'), color: AppTheme.success);
  }

  Future<void> _togglePin(bool enabled) async {
    if (enabled) {
      if (!PinHelper.hasAppPin) {
        await _setOrChangePin();
      } else {
        await appSettings.setPinEnabled(true);
        sessionController.refresh();
      }
    } else {
      if (!await _verifyCurrentPin()) return;
      await appSettings.setPinEnabled(false);
      sessionController.refresh();
    }
    if (mounted) setState(() {});
  }

  // ------------------------------------------------------------- printer

  Future<void> _choosePrinter() async {
    final l10n = context.l10n;
    final helper = PrinterHelper();
    await helper.checkPermission();
    final devices = await helper.getBondedDevices();
    if (!mounted) return;
    if (devices.isEmpty) {
      _snack(l10n.t('no_paired_devices'), color: AppTheme.warning);
      return;
    }
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(l10n.t('paired_devices'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final d in devices)
              ListTile(
                leading: const Icon(Icons.print_outlined),
                title: Text(d.name),
                subtitle: Text(d.macAdress),
                onTap: () {
                  Navigator.pop(sheet);
                  context.read<PrinterBloc>().add(
                      ConnectPrinterEvent(mac: d.macAdress, name: d.name));
                },
              ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.adaptive.arrow_back, color: theme.primaryColor),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/menu'),
        ),
      ),
      body: ValueListenableBuilder<AppSettings>(
        valueListenable: appSettings,
        builder: (context, settings, _) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 48),
            children: [
              _buildProfile(),
              const SizedBox(height: 16),
              _header(l10n.t('management')),
              _group([
                _tile(
                  icon: Icons.storefront,
                  title: l10n.t('shop_details'),
                  subtitle: l10n.t('edit_business_info'),
                  onTap: () => context.push('/shop'),
                ),
                _tile(
                  icon: Icons.qr_code_scanner,
                  title: l10n.products,
                  subtitle: l10n.t('manage_stock_barcodes'),
                  onTap: () => context.push('/products'),
                ),
                _tile(
                  icon: Icons.people_outline,
                  title: l10n.customers,
                  subtitle: l10n.t('manage_saved_customers'),
                  onTap: () => context.push('/customers'),
                ),
                _tile(
                  icon: Icons.manage_accounts_outlined,
                  title: l10n.users,
                  subtitle: l10n.t('users_subtitle'),
                  onTap: () => context.push('/users'),
                ),
                if (sessionController.isMultiUser)
                  _tile(
                    icon: Icons.logout_rounded,
                    title: l10n.t('sign_out'),
                    subtitle: sessionController.currentUser == null
                        ? ''
                        : '${sessionController.currentUser!.name} · '
                            '${l10n.t(sessionController.currentUser!.role.labelKey)}',
                    showChevron: false,
                    onTap: () async {
                      await sessionController.lock();
                      if (context.mounted) context.go('/login');
                    },
                  ),
              ]),
              const SizedBox(height: 20),
              _header(l10n.t('appearance')),
              _buildAppearance(),
              const SizedBox(height: 20),
              _header(l10n.t('general')),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(l10n.t('language')),
                    const SizedBox(height: 8),
                    _LanguagePicker(current: settings.locale),
                    const SizedBox(height: 18),
                    _label(l10n.t('currency')),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: TextField(
                            controller: _currencyController,
                            textAlign: TextAlign.center,
                            maxLength: 6,
                            decoration: InputDecoration(
                              labelText: l10n.t('currency_symbol'),
                              counterText: '',
                              isDense: true,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onChanged: (v) {
                              if (v.trim().isNotEmpty) {
                                appSettings.setCurrency(symbol: v);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: settings.decimalDigits,
                            decoration: InputDecoration(
                              labelText: l10n.t('decimals'),
                              isDense: true,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            items: const [
                              DropdownMenuItem(value: 0, child: Text('0')),
                              DropdownMenuItem(value: 1, child: Text('1')),
                              DropdownMenuItem(value: 2, child: Text('2')),
                              DropdownMenuItem(value: 3, child: Text('3')),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                appSettings.setCurrency(decimals: v);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.t('symbol_before_amount'),
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text(
                          l10n.t('currency_example',
                              {'amount': Money.format(1234.5)}),
                          style: const TextStyle(fontSize: 11)),
                      value: settings.currencySymbolBefore,
                      onChanged: (v) => appSettings.setCurrency(symbolBefore: v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.t('decimal_quantities'),
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text(l10n.t('decimal_quantities_hint'),
                          style: const TextStyle(fontSize: 11)),
                      value: settings.decimalQuantities,
                      onChanged: (v) => appSettings.setDecimalQuantities(v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _header(l10n.t('security')),
              _buildSecurity(settings),
              const SizedBox(height: 20),
              _header(l10n.t('hardware')),
              _buildPrinter(),
              const SizedBox(height: 20),
              _header(l10n.t('data')),
              _buildBackup(),
              const SizedBox(height: 20),
              _header(l10n.t('about')),
              _group([
                _tile(
                  icon: Icons.info_outline,
                  title: l10n.appTitle,
                  subtitle: l10n.t('version', {'version': _appVersion}),
                  showChevron: false,
                ),
              ]),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfile() {
    return BlocBuilder<ShopBloc, ShopState>(
      builder: (context, state) {
        String shopName = context.l10n.t('your_shop');
        if (state is ShopLoaded && state.shop.name.isNotEmpty) {
          shopName = state.shop.name;
        }
        final initials = shopName
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
            .join();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: Theme.of(context).brightness == Brightness.dark
                      ? null
                      : themeController.accent.gradient,
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.28),
                      blurRadius: 15,
                      spreadRadius: 3,
                    )
                  ],
                ),
                alignment: Alignment.center,
                child: Text(initials.isEmpty ? '?' : initials,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              Text(shopName,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              if (sessionController.currentUser != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                      context.l10n.t('logged_in_as',
                          {'name': sessionController.currentUser!.name}),
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSecurity(AppSettings settings) {
    final l10n = context.l10n;
    final multi = sessionController.isMultiUser;
    final hasPin = PinHelper.hasAppPin;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (multi)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.groups_outlined,
                      size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(l10n.t('multi_user_active'),
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.lock_outline),
            title: Text(l10n.t('pin_lock'),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            subtitle: Text(l10n.t('pin_lock_hint'),
                style: const TextStyle(fontSize: 11)),
            value: settings.pinEnabled && hasPin,
            onChanged: multi ? null : _togglePin,
          ),
          if (!multi)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _setOrChangePin,
                    icon: const Icon(Icons.password, size: 18),
                    label:
                        Text(hasPin ? l10n.t('change_pin') : l10n.t('set_pin')),
                  ),
                ),
                if (hasPin) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _removePin,
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.danger),
                      icon: const Icon(Icons.lock_open, size: 18),
                      label: Text(l10n.t('remove_pin')),
                    ),
                  ),
                ],
              ],
            ),
          if (sessionController.canLock)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => sessionController.lock(),
                  icon: const Icon(Icons.lock, size: 18),
                  label: Text(l10n.t('lock_app')),
                ),
              ),
            ),
          const Divider(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.manage_accounts_outlined),
            title: Text(l10n.t('multi_user'),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            subtitle: Text(l10n.t('multi_user_hint'),
                style: const TextStyle(fontSize: 11)),
            trailing: Icon(Icons.adaptive.arrow_forward, size: 18),
            onTap: () => context.push('/users'),
          ),
        ],
      ),
    );
  }

  Widget _buildPrinter() {
    final l10n = context.l10n;
    final box = HiveDatabase.settingsBox;
    return BlocConsumer<PrinterBloc, PrinterState>(
      listener: (context, state) {
        if (state.errorMessage != null &&
            (state.status == PrinterStatus.scanFailure ||
                state.status == PrinterStatus.connectionFailure)) {
          _snack(l10n.t(state.errorMessage!), color: AppTheme.danger);
        } else if (state.status == PrinterStatus.connected) {
          _snack(l10n.t('connected_to_printer'), color: AppTheme.success);
        }
      },
      builder: (context, state) {
        final busy = state.status == PrinterStatus.scanning ||
            state.status == PrinterStatus.connecting ||
            state.status == PrinterStatus.testPrinting;
        final paperWidth = box.get('paper_width') as int? ?? 58;
        final autoPrint = box.get('auto_print') == true;
        return _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.print,
                    color: state.connectedMac != null
                        ? Colors.teal
                        : Theme.of(context).disabledColor),
                title: Text(l10n.t('print_device'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Row(
                  children: [
                    Flexible(
                      child: Text(
                        state.connectedMac != null
                            ? (state.connectedName ??
                                l10n.t('printer_connected'))
                            : l10n.t('no_printer_connected'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    if (state.connectedMac != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10)),
                        child: Text(l10n.t('connected'),
                            style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal)),
                      ),
                    ],
                  ],
                ),
                trailing: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : IconButton(
                        tooltip: l10n.t('bluetooth_settings'),
                        icon: const Icon(Icons.settings_bluetooth),
                        onPressed: () =>
                            device_settings.AppSettings.openAppSettings(
                                type: device_settings
                                    .AppSettingsType.bluetooth),
                      ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  OutlinedButton.icon(
                    onPressed: busy ? null : _choosePrinter,
                    icon: const Icon(Icons.bluetooth_searching, size: 18),
                    label: Text(l10n.t('choose_printer')),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => context
                            .read<PrinterBloc>()
                            .add(RefreshPrinterEvent()),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(l10n.t('refresh')),
                  ),
                  if (state.connectedMac != null) ...[
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () => context
                              .read<PrinterBloc>()
                              .add(TestPrintEvent(_shopName())),
                      icon: const Icon(Icons.receipt_long, size: 18),
                      label: Text(l10n.t('test_print')),
                    ),
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () => context
                              .read<PrinterBloc>()
                              .add(DisconnectPrinterEvent()),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.danger),
                      icon: const Icon(Icons.link_off, size: 18),
                      label: Text(l10n.t('disconnect')),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              _label(l10n.t('paper_width')),
              const SizedBox(height: 6),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 58, label: Text('58 mm')),
                  ButtonSegment(value: 80, label: Text('80 mm')),
                ],
                selected: {paperWidth == 80 ? 80 : 58},
                onSelectionChanged: (s) async {
                  final w = s.first;
                  await box.put('paper_width', w);
                  if (mounted) setState(() {});
                },
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(l10n.t('paper_width_hint'),
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).textTheme.bodySmall?.color)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.t('auto_print'),
                    style: const TextStyle(fontSize: 13)),
                subtitle: Text(l10n.t('auto_print_hint'),
                    style: const TextStyle(fontSize: 11)),
                value: autoPrint,
                onChanged: (v) async {
                  await box.put('auto_print', v);
                  if (mounted) setState(() {});
                },
              ),
              Text(l10n.t('thermal_latin_note'),
                  style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).textTheme.bodySmall?.color)),
              const SizedBox(height: 4),
              Text(l10n.t('connect_hint'),
                  style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).textTheme.bodySmall?.color)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBackup() {
    final l10n = context.l10n;
    final last = BackupHelper.lastBackupAt();
    final lastText = last == null
        ? l10n.t('never')
        : DateFormat('dd/MM/yyyy HH:mm').format(last);
    return _card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _tile(
            icon: Icons.upload_file_outlined,
            title: l10n.t('export_backup'),
            subtitle: l10n.t('export_backup_subtitle'),
            trailing: _backingUp
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : null,
            onTap: _backingUp ? null : _exportBackup,
          ),
          _divider(),
          _tile(
            icon: Icons.content_copy_outlined,
            title: l10n.t('backup_copy_clipboard'),
            onTap: _copyBackupToClipboard,
          ),
          _divider(),
          _tile(
            icon: Icons.folder_open_outlined,
            title: l10n.t('import_backup'),
            subtitle: '${l10n.t('pick_file')} · ${l10n.t('import_backup_subtitle')}',
            onTap: _importFromFile,
          ),
          _divider(),
          _tile(
            icon: Icons.paste_outlined,
            title: l10n.t('paste_text'),
            subtitle: l10n.t('import_hint'),
            onTap: _importFromText,
          ),
          _divider(),
          _tile(
            icon: Icons.history,
            title: l10n.t('local_backups'),
            subtitle: l10n.t('last_backup', {'time': lastText}),
            onTap: _showLocalBackups,
          ),
          _divider(),
          SwitchListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            secondary: const Icon(Icons.schedule_outlined),
            title: Text(l10n.t('auto_backup'),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            subtitle: Text(l10n.t('auto_backup_hint'),
                style: const TextStyle(fontSize: 11)),
            value: BackupHelper.isAutoBackupEnabled(),
            onChanged: (v) async {
              await BackupHelper.setAutoBackupEnabled(v);
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------- appearance

  /// Theme mode + accent colour + density. Everything here is instant:
  /// [themeController] rebuilds MaterialApp on every change.
  Widget _buildAppearance() {
    final l10n = context.l10n;
    return ValueListenableBuilder<ThemeSettings>(
      valueListenable: themeController,
      builder: (context, theme, _) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(l10n.t('theme_mode')),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                      value: ThemeMode.light,
                      label: Text(l10n.t('light')),
                      icon: const Icon(Icons.light_mode_outlined, size: 18)),
                  ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text(l10n.t('dark')),
                      icon: const Icon(Icons.dark_mode_outlined, size: 18)),
                  ButtonSegment(
                      value: ThemeMode.system,
                      label: Text(l10n.t('auto')),
                      icon: const Icon(Icons.brightness_auto_outlined,
                          size: 18)),
                ],
                selected: {theme.mode},
                onSelectionChanged: (s) =>
                    themeController.setThemeMode(s.first),
              ),
            ),
            const SizedBox(height: 20),
            _label(l10n.t('accent_color')),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final accent in AppTheme.accents)
                  _AccentSwatch(
                    accent: accent,
                    selected: accent.id == theme.accentId,
                    label: l10n.t(accent.labelKey),
                    onTap: () => themeController.setAccent(accent.id),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.t('compact_mode'),
                  style: const TextStyle(fontSize: 13)),
              subtitle: Text(l10n.t('compact_mode_hint'),
                  style: const TextStyle(fontSize: 11)),
              value: theme.compact,
              onChanged: themeController.setCompact,
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- helpers

  Widget _header(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        child: Text(title.toUpperCase(),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: Theme.of(context).textTheme.bodySmall?.color)),
      );

  Widget _label(String text) => Text(text,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13));

  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) =>
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
        ),
        child: child,
      );

  Widget _group(List<Widget> tiles) => _card(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (int i = 0; i < tiles.length; i++) ...[
              if (i > 0) _divider(),
              tiles[i],
            ],
          ],
        ),
      );

  Widget _divider() => Divider(
      height: 1,
      indent: 56,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.4));

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool showChevron = true,
  }) =>
      ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: trailing ??
            (showChevron && onTap != null
                ? Icon(Icons.adaptive.arrow_forward,
                    size: 18, color: Theme.of(context).disabledColor)
                : null),
        onTap: onTap,
      );
}

class _LanguagePicker extends StatelessWidget {
  final Locale? current;
  const _LanguagePicker({required this.current});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = <MapEntry<String?, String>>[
      MapEntry(null, l10n.t('system_language')),
      MapEntry('ar', l10n.t('arabic')),
      MapEntry('fr', l10n.t('french')),
      MapEntry('en', l10n.t('english')),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(o.value),
            selected: current?.languageCode == o.key,
            onSelected: (_) =>
                appSettings.setLocale(o.key == null ? null : Locale(o.key!)),
          ),
      ],
    );
  }
}

/// A round colour chip used by the accent picker.
class _AccentSwatch extends StatelessWidget {
  final AccentPalette accent;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  const _AccentSwatch({
    required this.accent,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: accent.gradient,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.seed.withValues(alpha: selected ? 0.45 : 0.2),
                  blurRadius: selected ? 14 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: selected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                : null,
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 56,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}
