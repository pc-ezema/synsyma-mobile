class UserProfile {
  const UserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    this.address,
    this.photoUrl,
  });

  final String id;              // UUID → always a String
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String? address;
  final String? photoUrl;

  static const empty = UserProfile(id: '', firstName: '', lastName: '', email: '');

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final a = firstName.isNotEmpty ? firstName[0] : '';
    final b = lastName.isNotEmpty ? lastName[0] : '';
    return '$a$b'.toUpperCase();
  }

  factory UserProfile.fromJson(Map<String, dynamic> j) {
    String? clean(Object? v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return UserProfile(
      id: clean(j['id']) ?? '',                       // ← UUID as String
      firstName: j['first_name']?.toString() ?? '',
      lastName: j['last_name']?.toString() ?? '',
      email: j['email']?.toString() ?? '',
      phone: clean(j['phone']),
      address: clean(j['address']),
      photoUrl: clean(j['photo_url']),
    );
  }
}