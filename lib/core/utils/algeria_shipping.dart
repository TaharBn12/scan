/// The site's delivery price list, read out of `shipping_setup.sql`.
///
/// `public.shipping_rates` is seeded with these 58 rows and is publicly
/// readable, so this copy is only the offline fallback the checkout uses
/// before the first query answers.
class WilayaRate {
  final int code;
  final String name;
  final double home;
  final double desk;

  const WilayaRate(this.code, this.name, this.home, this.desk);
}

const List<WilayaRate> kDefaultShippingRates = [
  WilayaRate(1, 'أدرار', 1200, 800),
  WilayaRate(2, 'الشلف', 700, 400),
  WilayaRate(3, 'الأغواط', 900, 500),
  WilayaRate(4, 'أم البواقي', 800, 500),
  WilayaRate(5, 'باتنة', 800, 500),
  WilayaRate(6, 'بجاية', 700, 400),
  WilayaRate(7, 'بسكرة', 900, 600),
  WilayaRate(8, 'بشار', 1000, 700),
  WilayaRate(9, 'البليدة', 500, 300),
  WilayaRate(10, 'البويرة', 600, 400),
  WilayaRate(11, 'تمنراست', 1500, 1000),
  WilayaRate(12, 'تبسة', 900, 600),
  WilayaRate(13, 'تلمسان', 800, 500),
  WilayaRate(14, 'تيارت', 800, 500),
  WilayaRate(15, 'تيزي وزو', 600, 400),
  WilayaRate(16, 'الجزائر', 400, 200),
  WilayaRate(17, 'الجلفة', 800, 500),
  WilayaRate(18, 'جيجل', 800, 500),
  WilayaRate(19, 'سطيف', 700, 400),
  WilayaRate(20, 'سعيدة', 800, 500),
  WilayaRate(21, 'سكيكدة', 800, 500),
  WilayaRate(22, 'سيدي بلعباس', 800, 500),
  WilayaRate(23, 'عنابة', 800, 500),
  WilayaRate(24, 'قالمة', 800, 500),
  WilayaRate(25, 'قسنطينة', 700, 400),
  WilayaRate(26, 'المدية', 600, 400),
  WilayaRate(27, 'مستغانم', 700, 400),
  WilayaRate(28, 'المسيلة', 800, 500),
  WilayaRate(29, 'معسكر', 800, 500),
  WilayaRate(30, 'ورقلة', 1000, 700),
  WilayaRate(31, 'وهران', 700, 400),
  WilayaRate(32, 'البيض', 900, 600),
  WilayaRate(33, 'إليزي', 1500, 1000),
  WilayaRate(34, 'برج بوعريريج', 700, 400),
  WilayaRate(35, 'بومرداس', 500, 300),
  WilayaRate(36, 'الطارف', 900, 600),
  WilayaRate(37, 'تندوف', 1500, 1000),
  WilayaRate(38, 'تيسمسيلت', 800, 500),
  WilayaRate(39, 'الوادي', 1000, 700),
  WilayaRate(40, 'خنشلة', 900, 600),
  WilayaRate(41, 'سوق أهراس', 900, 600),
  WilayaRate(42, 'تيبازة', 500, 300),
  WilayaRate(43, 'ميلة', 700, 400),
  WilayaRate(44, 'عين الدفلى', 600, 400),
  WilayaRate(45, 'النعامة', 1000, 700),
  WilayaRate(46, 'عين تموشنت', 800, 500),
  WilayaRate(47, 'غرداية', 900, 600),
  WilayaRate(48, 'غليزان', 700, 400),
  WilayaRate(49, 'تيميمون', 1400, 900),
  WilayaRate(50, 'برج باجي مختار', 1800, 1200),
  WilayaRate(51, 'أولاد جلال', 900, 600),
  WilayaRate(52, 'بني عباس', 1300, 800),
  WilayaRate(53, 'عين صالح', 1400, 900),
  WilayaRate(54, 'عين قزام', 1800, 1200),
  WilayaRate(55, 'تقرت', 1000, 700),
  WilayaRate(56, 'جانت', 1600, 1100),
  WilayaRate(57, 'المغير', 900, 600),
  WilayaRate(58, 'المنيعة', 1100, 800),
];

/// The two prices for one wilaya, or null when the code is unknown.
WilayaRate? defaultRateFor(int wilayaCode) {
  for (final r in kDefaultShippingRates) {
    if (r.code == wilayaCode) return r;
  }
  return null;
}
