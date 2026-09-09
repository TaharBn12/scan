/// Cross-script product search built for how Algerian shopkeepers actually
/// type: an Arabic catalogue searched with a Latin (or "Arabizi") keyboard,
/// and vice-versa.
///
/// `حليب` is found by typing `hlib`, `7lib` or `halib`;
/// `قهوة` by `kahwa` or `9ahwa`; `شوكولاطة` by `chocolat`.
///
/// How it works: both the product text and the query are reduced to a
/// *consonant skeleton* in a single alphabet. Vowels (the part people spell
/// inconsistently) are dropped, look-alike consonants are merged
/// (ق/ك → k, س/ص/ش → s …), Latin digraphs are folded (ch/sh → s, kh → h,
/// ou → w) and Arabizi digits are decoded (3 → ع, 7 → ح, 9 → ق, 5 → خ).
/// Two skeleton variants are produced for the و/w sound, which is written
/// either way, and a match is a hit when any variant contains the query.
class SearchText {
  SearchText._();

  /// Arabic letter -> merged Latin consonant. Letters that behave like
  /// vowels (ا أ إ آ ى ء ؤ ئ ع ي) are dropped on purpose.
  static const Map<String, String> _arabic = {
    'ب': 'b', 'پ': 'b',
    'ت': 't', 'ث': 't', 'ط': 't',
    'ج': 'j', 'چ': 'j',
    'ح': 'h', 'خ': 'h', 'ه': 'h', 'ة': 'h',
    'د': 'd', 'ذ': 'd', 'ض': 'd', 'ظ': 'd',
    'ر': 'r',
    'ز': 'z',
    'س': 's', 'ص': 's', 'ش': 's',
    'غ': 'g', 'ڤ': 'g', 'ﭬ': 'g',
    'ف': 'f',
    'ق': 'k', 'ك': 'k', 'گ': 'k',
    'ل': 'l',
    'م': 'm',
    'ن': 'n',
    'و': 'w', 'ؤ': 'w',
  };

  /// Arabic letters that carry no consonant value for matching purposes.
  static const String _arabicSilent = 'اأإآىءئيًٌٍَُِّْـ';

  /// Latin digraphs, folded before single letters are processed.
  static const List<List<String>> _digraphs = [
    ['tch', 'j'],
    ['dj', 'j'],
    ['ch', 's'],
    ['sh', 's'],
    ['kh', 'h'],
    ['gh', 'g'],
    ['th', 't'],
    ['ph', 'f'],
    ['ou', 'w'],
    ['oo', 'w'],
    ['ck', 'k'],
  ];

  /// "Arabizi" digits used inside Latin words.
  static const Map<String, String> _arabizi = {
    '2': '', // ء
    '3': '', // ع
    '5': 'h', // خ
    '7': 'h', // ح
    '8': 'g', // غ
    '9': 'k', // ق
  };

  static const String _latinVowels = 'aeiouy';

  static const Map<String, String> _accents = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'î': 'i', 'ï': 'i', 'í': 'i',
    'ò': 'o', 'ô': 'o', 'ö': 'o', 'ó': 'o', 'õ': 'o',
    'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
    'ç': 's', 'ñ': 'n',
  };

  /// Lower-cased, accent- and diacritic-free text used for plain substring
  /// matching (barcodes, numbers, exact spellings).
  static const String _diacritics = 'ًٌٍَُِّْـ';

  static String normalize(String input) {
    final buffer = StringBuffer();
    for (final ch in input.toLowerCase().split('')) {
      if (_diacritics.contains(ch)) continue; // harakat + tatweel
      buffer.write(_accents[ch] ?? ch);
    }
    return buffer
        .toString()
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .trim();
  }

  /// The one or two consonant skeletons of [input].
  static Set<String> skeletons(String input) {
    final folded = _fold(input);
    final withW = _reduce(folded, dropW: false);
    final withoutW = _reduce(folded, dropW: true);
    return {
      if (withW.isNotEmpty) withW,
      if (withoutW.isNotEmpty) withoutW,
    };
  }

  /// Folds Arabic letters, digraphs and Arabizi digits into plain Latin.
  static String _fold(String input) {
    var text = normalize(input);
    for (final pair in _digraphs) {
      text = text.replaceAll(pair[0], pair[1]);
    }
    final buffer = StringBuffer();
    for (final ch in text.split('')) {
      final arabic = _arabic[ch];
      if (arabic != null) {
        buffer.write(arabic);
        continue;
      }
      if (_arabicSilent.contains(ch)) continue; // ا ي ء …
      if (ch == 'ع' || ch == 'ئ') continue;
      final arabizi = _arabizi[ch];
      if (arabizi != null) {
        buffer.write(arabizi);
        continue;
      }
      switch (ch) {
        case 'c':
        case 'q':
          buffer.write('k');
          break;
        case 'x':
          buffer.write('ks');
          break;
        case 'v':
          buffer.write('f');
          break;
        default:
          buffer.write(ch);
      }
    }
    return buffer.toString();
  }

  /// Drops vowels, spacing and punctuation, then collapses doubles.
  static String _reduce(String folded, {required bool dropW}) {
    final buffer = StringBuffer();
    String? previous;
    for (final ch in folded.split('')) {
      if (_latinVowels.contains(ch)) continue;
      if (dropW && ch == 'w') continue;
      final isWord = (ch.codeUnitAt(0) >= 97 && ch.codeUnitAt(0) <= 122) ||
          (ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57);
      if (!isWord) continue;
      if (ch == previous) continue; // sukkar -> skr
      buffer.write(ch);
      previous = ch;
    }
    return buffer.toString();
  }

  /// True when [query] should match [source] (empty query matches).
  static bool matches(String source, String query) {
    final q = query.trim();
    if (q.isEmpty) return true;
    final normalizedSource = normalize(source);
    final normalizedQuery = normalize(q);
    if (normalizedQuery.isEmpty) return true;
    if (normalizedSource.contains(normalizedQuery)) return true;

    final querySkeletons = skeletons(q);
    if (querySkeletons.isEmpty) return false;
    // One-letter skeletons are too weak: they would match almost everything.
    if (querySkeletons.every((s) => s.length < 2)) return false;

    final sourceSkeletons = skeletons(source);
    for (final s in sourceSkeletons) {
      for (final qs in querySkeletons) {
        if (qs.length >= 2 && s.contains(qs)) return true;
      }
    }
    return false;
  }

  /// True when any of [sources] matches [query].
  static bool matchesAny(Iterable<String?> sources, String query) {
    if (query.trim().isEmpty) return true;
    for (final source in sources) {
      if (source == null || source.isEmpty) continue;
      if (matches(source, query)) return true;
    }
    return false;
  }
}
