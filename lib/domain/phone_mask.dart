class PhoneMask {
  static const country = '591';

  static String digits(String raw) => raw.replaceAll(RegExp(r'\D'), '');

  static String display(String raw) {
    var local = digits(raw);
    if (local.startsWith(country)) {
      local = local.substring(country.length);
    }
    if (local.isEmpty) return '';
    if (local.length <= 4) return '+$country ••••';
    return '+$country ${local.substring(0, local.length - 4)} ••••';
  }

  static String whatsapp(String raw) {
    var value = digits(raw);
    if (value.startsWith('00')) value = value.substring(2);
    if (value.isEmpty) return '';
    if (!value.startsWith(country)) value = '$country$value';
    return value;
  }
}
