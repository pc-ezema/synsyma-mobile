import 'regions.dart';

/// One suggestion from the server's address search.
class AddressSuggestion {
  const AddressSuggestion({
    required this.label,
    required this.addressLine1,
    required this.city,
    required this.region,
    required this.postalCode,
    required this.country,
  });

  final String label;
  final String addressLine1;
  final String city;
  final String region;
  final String postalCode;
  final String country;

  factory AddressSuggestion.fromJson(Map<String, dynamic> j) => AddressSuggestion(
        label: '${j['label'] ?? ''}',
        addressLine1: '${j['address_line1'] ?? ''}',
        city: '${j['city'] ?? ''}',
        region: '${j['region'] ?? ''}',
        postalCode: '${j['postal_code'] ?? ''}',
        country: '${j['country'] ?? ''}',
      );
}

String _plain(String s) {
  const from = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyy';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().trim().split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString();
}

/// The province, state or nation from the form's own list that matches what the search returned, or null.
String? matchRegion(String country, String? name) {
  if (name == null || name.trim().isEmpty) return null;
  final n = _plain(name);
  for (final r in regionsByCountry[country] ?? const <String>[]) {
    if (_plain(r) == n) return r;
  }
  return null;
}