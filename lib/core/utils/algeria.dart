/// The 58 Algerian wilayas with their default cash-on-delivery fees.
///
/// The storefront's checkout and the console's shipping screen both read from
/// here, so a shop never has to type 58 rows by hand — it opens the shipping
/// table with sane numbers already in it and edits the few that differ.
///
/// [code] is the official wilaya number, which is what most Algerian
/// storefront schemas store in an order row, so it doubles as the join key
/// when the site's `algeria_cities` table is keyed that way.
class Wilaya {
  final int code;
  final String nameAr;
  final String nameFr;
  final double homeFee;
  final double stopDeskFee;

  const Wilaya({
    required this.code,
    required this.nameAr,
    required this.nameFr,
    this.homeFee = 800,
    this.stopDeskFee = 450,
  });

  String name(String languageCode) =>
      languageCode == 'ar' ? nameAr : nameFr;

  @override
  String toString() => 'Wilaya($code $nameFr)';
}

class Algeria {
  const Algeria._();

  /// Wilayas grouped by delivery cost, because that is how the fees really
  /// work: Algiers and its neighbours are cheap, the deep south is not.
  static const List<Wilaya> wilayas = [
    Wilaya(code: 1, nameAr: 'أدرار', nameFr: 'Adrar', homeFee: 900, stopDeskFee: 600),
    Wilaya(code: 2, nameAr: 'الشلف', nameFr: 'Chlef', homeFee: 700, stopDeskFee: 450),
    Wilaya(code: 3, nameAr: 'الأغواط', nameFr: 'Laghouat', homeFee: 800, stopDeskFee: 500),
    Wilaya(code: 4, nameAr: 'أم البواقي', nameFr: 'Oum El Bouaghi', homeFee: 700, stopDeskFee: 450),
    Wilaya(code: 5, nameAr: 'باتنة', nameFr: 'Batna', homeFee: 700, stopDeskFee: 450),
    Wilaya(code: 6, nameAr: 'بجاية', nameFr: 'Béjaïa', homeFee: 700, stopDeskFee: 450),
    Wilaya(code: 7, nameAr: 'بسكرة', nameFr: 'Biskra', homeFee: 800, stopDeskFee: 500),
    Wilaya(code: 8, nameAr: 'بشار', nameFr: 'Béchar', homeFee: 900, stopDeskFee: 600),
    Wilaya(code: 9, nameAr: 'البليدة', nameFr: 'Blida', homeFee: 500, stopDeskFee: 350),
    Wilaya(code: 10, nameAr: 'البويرة', nameFr: 'Bouira', homeFee: 600, stopDeskFee: 400),
    Wilaya(code: 11, nameAr: 'تمنراست', nameFr: 'Tamanrasset', homeFee: 1300, stopDeskFee: 800),
    Wilaya(code: 12, nameAr: 'تبسة', nameFr: 'Tébessa', homeFee: 700, stopDeskFee: 450),
    Wilaya(code: 13, nameAr: 'تلمسان', nameFr: 'Tlemcen', homeFee: 700, stopDeskFee: 450),
    Wilaya(code: 14, nameAr: 'تيارت', nameFr: 'Tiaret', homeFee: 700, stopDeskFee: 450),
    Wilaya(code: 15, nameAr: 'تيزي وزو', nameFr: 'Tizi Ouzou', homeFee: 600, stopDeskFee: 400),
    Wilaya(code: 16, nameAr: 'الجزائر', nameFr: 'Alger', homeFee: 400, stopDeskFee: 300),
    Wilaya(code: 17, nameAr: 'الجلفة', nameFr: 'Djelfa', homeFee: 800, stopDeskFee: 500),
    Wilaya(code: 18, nameAr: 'جيجل', nameFr: 'Jijel', homeFee: 700, stopDeskFee: 450),
    Wilaya(code: 19, nameAr: 'سطيف', nameFr: 'Sétif', homeFee: 600, stopDeskFee: 400),
    Wilaya(code: 20, nameAr: 'سعيدة', nameFr: 'Saïda', homeFee: 700, stopDeskFee: 450),
    Wilaya(code: 21, nameAr: 'سكيكدة', nameFr: 'Skikda', homeFee: 700, stopDeskFee: 450),
    Wilaya(code: 22, nameAr: 'سيدي بلعباس', nameFr: 'Sidi Bel Abbès', homeFee: 700, stopDeskFee: 450),
    Wilaya(code: 23, nameAr: 'عنابة', nameFr: 'Annaba', homeFee: 700, stopDeskFee: 450),
    Wilaya(code: 24, nameAr: 'قالمة', nameFr: 'Guelma', homeFee: 700, stopDeskFee: 450),
    Wilaya(code: 25, nameAr: 'قسنطينة', nameFr: 'Constantine', homeFee: 600, stopDeskFee: 400),
    Wilaya(code: 26, nameAr: 'المدية', nameFr: 'Médéa', homeFee: 600, stopDeskFee: 400),
    Wilaya(code: 27, nameAr: 'مستغانم', nameFr: 'Mostaganem', homeFee: 700, stopDeskFee: 450),
    Wilaya(code: 28, nameAr: 'المسيلة', nameFr: 'M\'Sila', homeFee: 700, stopDeskFee: 450),
    Wilaya(code: 29, nameAr: 'معسكر', nameFr: 'Mascara', homeFee: 700, stopDeskFee: 450),
    Wilaya(code: 30, nameAr: 'ورقلة', nameFr: 'Ouargla', homeFee: 900, stopDeskFee: 600),
    Wilaya(code: 31, nameAr: 'وهران', nameFr: 'Oran', homeFee: 600, stopDeskFee: 400),
    Wilaya(code: 32, nameAr: 'البيض', nameFr: 'El Bayadh', homeFee: 800, stopDeskFee: 500),
    Wilaya(code: 33, nameAr: 'إليزي', nameFr: 'Illizi', homeFee: 1200, stopDeskFee: 750),
    Wilaya(code: 34, nameAr: 'برج بوعريريج', nameFr: 'Bordj Bou Arréridj', homeFee: 600, stopDeskFee: 400),
    Wilaya(code: 35, nameAr: 'بومرداس', nameFr: 'Boumerdès', homeFee: 500, stopDeskFee: 350),
    Wilaya(code: 36, nameAr: 'الطارف', nameFr: 'El Tarf', homeFee: 700, stopDeskFee: 450),
    Wilaya(code: 37, nameAr: 'تندوف', nameFr: 'Tindouf', homeFee: 1100, stopDeskFee: 700),
    Wilaya(code: 38, nameAr: 'تيسمسيلت', nameFr: 'Tissemsilt', homeFee: 700, stopDeskFee: 450),
    Wilaya(code: 39, nameAr: 'الوادي', nameFr: 'El Oued', homeFee: 900, stopDeskFee: 600),
    Wilaya(code: 40, nameAr: 'خنشلة', nameFr: 'Khenchela', homeFee: 700, stopDeskFee: 450),
    Wilaya(code: 41, nameAr: 'سوق أهراس', nameFr: 'Souk Ahras', homeFee: 700, stopDeskFee: 450),
    Wilaya(code: 42, nameAr: 'تيبازة', nameFr: 'Tipaza', homeFee: 500, stopDeskFee: 350),
    Wilaya(code: 43, nameAr: 'ميلة', nameFr: 'Mila', homeFee: 700, stopDeskFee: 450),
    Wilaya(code: 44, nameAr: 'عين الدفلى', nameFr: 'Aïn Defla', homeFee: 600, stopDeskFee: 400),
    Wilaya(code: 45, nameAr: 'النعامة', nameFr: 'Naâma', homeFee: 800, stopDeskFee: 500),
    Wilaya(code: 46, nameAr: 'عين تموشنت', nameFr: 'Aïn Témouchent', homeFee: 700, stopDeskFee: 450),
    Wilaya(code: 47, nameAr: 'غرداية', nameFr: 'Ghardaïa', homeFee: 900, stopDeskFee: 600),
    Wilaya(code: 48, nameAr: 'غليزان', nameFr: 'Relizane', homeFee: 700, stopDeskFee: 450),
    Wilaya(code: 49, nameAr: 'تيميمون', nameFr: 'Timimoun', homeFee: 1000, stopDeskFee: 650),
    Wilaya(code: 50, nameAr: 'برج باجي مختار', nameFr: 'Bordj Badji Mokhtar', homeFee: 1300, stopDeskFee: 800),
    Wilaya(code: 51, nameAr: 'أولاد جلال', nameFr: 'Ouled Djellal', homeFee: 900, stopDeskFee: 600),
    Wilaya(code: 52, nameAr: 'بني عباس', nameFr: 'Béni Abbès', homeFee: 1000, stopDeskFee: 650),
    Wilaya(code: 53, nameAr: 'إن قزام', nameFr: 'In Guezzam', homeFee: 1300, stopDeskFee: 800),
    Wilaya(code: 54, nameAr: 'تقرت', nameFr: 'Touggourt', homeFee: 900, stopDeskFee: 600),
    Wilaya(code: 55, nameAr: 'جانت', nameFr: 'Djanet', homeFee: 1300, stopDeskFee: 800),
    Wilaya(code: 56, nameAr: 'المغير', nameFr: 'El M\'Ghair', homeFee: 900, stopDeskFee: 600),
    Wilaya(code: 57, nameAr: 'المنيعة', nameFr: 'El Meniaa', homeFee: 1000, stopDeskFee: 650),
    Wilaya(code: 58, nameAr: 'عين صالح', nameFr: 'In Salah', homeFee: 1100, stopDeskFee: 700),
  ];

  /// Lookup by the official code; null when unknown (the caller falls back
  /// to the store's default fee rather than charging nothing).
  static Wilaya? byCode(int code) {
    for (final w in wilayas) {
      if (w.code == code) return w;
    }
    return null;
  }

  /// Lookup by name in either language, forgiving accents and case — this is
  /// what matches a free-text "wilaya" column coming from the website.
  static Wilaya? byName(String raw) {
    final needle = _fold(raw);
    if (needle.isEmpty) return null;
    for (final w in wilayas) {
      if (_fold(w.nameFr) == needle || _fold(w.nameAr) == needle) return w;
    }
    // Prefix match handles "Alger Centre", "Oran Ouest"…
    for (final w in wilayas) {
      if (_fold(w.nameFr).startsWith(needle) || _fold(w.nameAr).startsWith(needle)) {
        return w;
      }
    }
    return null;
  }

  /// The fee for a delivery to [rawWilaya], or [fallback].
  static double feeFor(String rawWilaya, {double fallback = 0, bool stopDesk = false}) {
    final found = byName(rawWilaya) ?? byCode(int.tryParse(rawWilaya.trim()) ?? -1);
    if (found == null) return fallback;
    return stopDesk ? found.stopDeskFee : found.homeFee;
  }

  /// Normalises a wilaya name for matching: a raw string cannot contain its
  /// own quote, so the apostrophe class is written as a normal double-quoted
  /// string (it covers both the ASCII and the typographic apostrophe).
  static String _fold(String raw) => raw
      .toLowerCase()
      .replaceAll(RegExp("['\u2019\u02bc]"), '')
      .replaceAll(RegExp('[àáâä]'), 'a')
      .replaceAll(RegExp('[èéêë]'), 'e')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u')
      .replaceAll(RegExp('ç'), 'c')
      .trim();
}
