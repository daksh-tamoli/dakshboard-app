// ============================================================
// DAKSHboard — Athlete Model
// ============================================================

class Athlete {
  final int id;
  final String firstname;
  final String lastname;
  final String? profileUrl;
  final String? city;
  final String? country;

  Athlete({
    required this.id,
    required this.firstname,
    required this.lastname,
    this.profileUrl,
    this.city,
    this.country,
  });

  factory Athlete.fromJson(Map<String, dynamic> json) {
    return Athlete(
      id: json['id'],
      firstname: json['firstname'] ?? '',
      lastname: json['lastname'] ?? '',
      profileUrl: json['profile'] ?? json['profile_medium'],
      city: json['city'],
      country: json['country'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'firstname': firstname,
    'lastname': lastname,
    'profile': profileUrl,
    'city': city,
    'country': country,
  };

  String get fullName => '$firstname $lastname'.trim();
  String get initials => '${firstname.isNotEmpty ? firstname[0] : ''}${lastname.isNotEmpty ? lastname[0] : ''}'.toUpperCase();
}
