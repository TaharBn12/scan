import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'strings_ar.dart';
import 'strings_en.dart';
import 'strings_fr.dart';

/// Lightweight localization: a flat key -> string map per language.
///
/// Usage: `context.l10n.products` or `context.l10n.t('products')`.
/// Missing keys fall back to English, then to the key itself, so a typo can
/// never crash the app. Arabic is the default when the device language is
/// not supported (the app is built for Algerian shops).
class AppLocalizations {
  final Locale locale;
  final Map<String, String> _strings;

  AppLocalizations(this.locale)
      : _strings = switch (locale.languageCode) {
          'ar' => stringsAr,
          'fr' => stringsFr,
          _ => stringsEn,
        };

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static const List<Locale> supportedLocales = [
    Locale('ar'),
    Locale('fr'),
    Locale('en'),
  ];

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  bool get isRtl => locale.languageCode == 'ar';

  /// Translate [key], substituting `{name}` placeholders from [args].
  String t(String key, [Map<String, Object?> args = const {}]) {
    String value = _strings[key] ?? stringsEn[key] ?? key;
    args.forEach((k, v) {
      value = value.replaceAll('{$k}', '$v');
    });
    return value;
  }

  // ---- Frequently used keys as getters (typo-safe at call sites) ----
  String get appTitle => t('app_title');
  String get menu => t('menu');
  String get sell => t('sell');
  String get manage => t('manage');
  String get more => t('more');
  String get scanAndBill => t('scan_and_bill');
  String get cameraCheckout => t('camera_checkout');
  String get noBarcodeItems => t('no_barcode_items');
  String get addToInvoice => t('add_to_invoice');
  String get products => t('products');
  String get stockAndPricing => t('stock_and_pricing');
  String get customers => t('customers');
  String get crmAndCredit => t('crm_and_credit');
  String get reports => t('reports');
  String get salesAndProfit => t('sales_and_profit');
  String get shopDetails => t('shop_details');
  String get businessInfo => t('business_info');
  String get settings => t('settings');
  String get settingsSubtitle => t('settings_subtitle');
  String get expenses => t('expenses');
  String get expensesSubtitle => t('expenses_subtitle');
  String get lowStock => t('low_stock');
  String get lowStockSubtitle => t('low_stock_subtitle');
  String get purchases => t('purchases');
  String get purchasesSubtitle => t('purchases_subtitle');
  String get labels => t('labels');
  String get labelsSubtitle => t('labels_subtitle');
  String get users => t('users');
  String get usersSubtitle => t('users_subtitle');
  String get todaysSales => t('todays_sales');
  String get yourShop => t('your_shop');
  String get cancel => t('cancel');
  String get confirm => t('confirm');
  String get share => t('share');
  String get print => t('print');
  String get customer => t('customer');
  String get amount => t('amount');
  String get category => t('category');
  String get stock => t('stock');
  String get remove => t('remove');
  String get close => t('close');
  String get save => t('save');
  String get delete => t('delete');
  String get edit => t('edit');
  String get add => t('add');
  String get done => t('done');
  String get ok => t('ok');
  String get yes => t('yes');
  String get no => t('no');
  String get search => t('search');
  String get all => t('all');
  String get total => t('total');
  String get subtotal => t('subtotal');
  String get discount => t('discount');
  String get grandTotal => t('grand_total');
  String get quantity => t('quantity');
  String get price => t('price');
  String get name => t('name');
  String get phone => t('phone');
  String get address => t('address');
  String get notes => t('notes');
  String get date => t('date');
  String get today => t('today');
  String get thisWeek => t('this_week');
  String get thisMonth => t('this_month');
  String get error => t('error');
  String get loading => t('loading');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
