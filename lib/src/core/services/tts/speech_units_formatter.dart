/// Formats scientific measurements, electricity, and SI units into natural spoken words.
class SpeechUnitsFormatter {
  const SpeechUnitsFormatter._();

  /// Normalizes scientific measurements, electricity, and SI units into natural spoken words.
  static String normalizeUnits(String input) {
    var text = input;

    // Compound units with /
    text = text
        .replaceAll(
          RegExp(r'\bkm/h\b', caseSensitive: false),
          'kilometers per hour',
        )
        .replaceAll(
          RegExp(r'\bm/s\^?2\b', caseSensitive: false),
          'meters per second squared',
        )
        .replaceAll(
          RegExp(r'\bm/s²\b', caseSensitive: false),
          'meters per second squared',
        )
        .replaceAll(
          RegExp(r'\bm/s\b', caseSensitive: false),
          'meters per second',
        )
        .replaceAll(
          RegExp(r'\bkg/m\^?3\b', caseSensitive: false),
          'kilograms per cubic meter',
        )
        .replaceAll(
          RegExp(r'\bkg/m³\b', caseSensitive: false),
          'kilograms per cubic meter',
        )
        .replaceAll(
          RegExp(r'\bg/cm\^?3\b', caseSensitive: false),
          'grams per cubic centimeter',
        )
        .replaceAll(
          RegExp(r'\bg/cm³\b', caseSensitive: false),
          'grams per cubic centimeter',
        )
        .replaceAll(
          RegExp(r'\brad/s\b', caseSensitive: false),
          'radians per second',
        )
        .replaceAll(
          RegExp(r'\brev/min\b', caseSensitive: false),
          'revolutions per minute',
        )
        .replaceAll(
          RegExp(r'\bmiles/h\b', caseSensitive: false),
          'miles per hour',
        )
        .replaceAll(
          RegExp(r'\bmol/dm\^?3\b', caseSensitive: false),
          'moles per decimeter cubed',
        )
        .replaceAll(
          RegExp(r'\bmol/dm³\b', caseSensitive: false),
          'moles per decimeter cubed',
        )
        .replaceAll(
          RegExp(r'\bmol/L\b', caseSensitive: false),
          'moles per liter',
        )
        .replaceAll(
          RegExp(r'\bft/s\b', caseSensitive: false),
          'feet per second',
        )
        .replaceAll(
          RegExp(r'\bbytes/s\b', caseSensitive: false),
          'bytes per second',
        )
        .replaceAll(
          RegExp(r'\bkb/s\b', caseSensitive: false),
          'kilobits per second',
        )
        .replaceAll(
          RegExp(r'\bmb/s\b', caseSensitive: false),
          'megabits per second',
        );

    // Units attached to numbers (e.g. 10μF, 5V, 4A, 2kg, 30kJ, 500Hz)
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:μ|u|mu|micro)\s*F\b', caseSensitive: false),
      (m) => '${m[1]} microfarads',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:nF)\b'),
      (m) => '${m[1]} nanofarads',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:pF)\b'),
      (m) => '${m[1]} picofarads',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:mF)\b'),
      (m) => '${m[1]} millifarads',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:kHz)\b', caseSensitive: false),
      (m) => '${m[1]} kilohertz',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:MHz)\b'),
      (m) => '${m[1]} megahertz',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:GHz)\b'),
      (m) => '${m[1]} gigahertz',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:Hz)\b', caseSensitive: false),
      (m) => '${m[1]} hertz',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:kJ)\b', caseSensitive: false),
      (m) => '${m[1]} kilojoules',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:mJ)\b'),
      (m) => '${m[1]} millijoules',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:MJ)\b'),
      (m) => '${m[1]} megajoules',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*J\b'),
      (m) => '${m[1]} joules',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:kN)\b', caseSensitive: false),
      (m) => '${m[1]} kilonewtons',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*N\b'),
      (m) => '${m[1]} newtons',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:kW)\b', caseSensitive: false),
      (m) => '${m[1]} kilowatts',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:MW)\b'),
      (m) => '${m[1]} megawatts',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*W\b'),
      (m) => '${m[1]} watts',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:kΩ|kOmega)\b', caseSensitive: false),
      (m) => '${m[1]} kilo-ohms',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:MΩ|MOmega)\b'),
      (m) => '${m[1]} mega-ohms',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:Ω|Omega|ohms?)\b', caseSensitive: false),
      (m) => '${m[1]} ohms',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:kV)\b', caseSensitive: false),
      (m) => '${m[1]} kilovolts',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:mV)\b'),
      (m) => '${m[1]} millivolts',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*V\b'),
      (m) => '${m[1]} volts',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:mA)\b'),
      (m) => '${m[1]} milliamperes',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*A\b'),
      (m) => '${m[1]} amperes',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*T\b'),
      (m) => '${m[1]} teslas',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:kg)\b', caseSensitive: false),
      (m) => '${m[1]} kilograms',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:mg)\b', caseSensitive: false),
      (m) => '${m[1]} milligrams',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:km)\b', caseSensitive: false),
      (m) => '${m[1]} kilometers',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:cm)\b', caseSensitive: false),
      (m) => '${m[1]} centimeters',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:mm)\b', caseSensitive: false),
      (m) => '${m[1]} millimeters',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:nm)\b', caseSensitive: false),
      (m) => '${m[1]} nanometers',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*m\b'),
      (m) => '${m[1]} meters',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:mL)\b', caseSensitive: false),
      (m) => '${m[1]} milliliters',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*L\b'),
      (m) => '${m[1]} liters',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:ms)\b'),
      (m) => '${m[1]} milliseconds',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*s\b'),
      (m) => '${m[1]} seconds',
    );

    return text;
  }
}
