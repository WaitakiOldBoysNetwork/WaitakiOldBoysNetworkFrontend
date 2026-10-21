class Profile {
  final String id;
  final String? userId;
  final String? firstName;
  final String? lastName;
  final String? headline;
  final int? gradYear;
  final String? city;
  final String? avatarUrl;
  final DateTime? createdAt;

  Profile({
    required this.id,
    this.userId,
    this.firstName,
    this.lastName,
    this.headline,
    this.gradYear,
    this.city,
    this.avatarUrl,
    this.createdAt,
  });

  String get fullName {
    final first = (firstName ?? '').trim();
    final last = (lastName ?? '').trim();
    if (first.isEmpty && last.isEmpty) return 'Alumni Member';
    if (first.isEmpty) return last;
    if (last.isEmpty) return first;
    return '$first $last';
  }

  String get initials {
    final first = (firstName ?? '').trim();
    final last = (lastName ?? '').trim();
    String result = '';
    if (first.isNotEmpty) result += first[0].toUpperCase();
    if (last.isNotEmpty) result += last[0].toUpperCase();
    if (result.isEmpty) return 'WB';
    return result;
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: (json['id'] ?? json['user_id'] ?? '').toString(),
      userId: json['user_id']?.toString(),
      firstName: json['first_name']?.toString(),
      lastName: json['last_name']?.toString(),
      headline: json['headline']?.toString(),
      gradYear: json['grad_year'] != null
          ? int.tryParse(json['grad_year'].toString())
          : null,
      city: json['city']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (userId != null) 'user_id': userId,
      'first_name': firstName,
      'last_name': lastName,
      'headline': headline,
      'grad_year': gradYear,
      'city': city,
      'avatar_url': avatarUrl,
    };
  }

  Profile copyWith({
    String? id,
    String? userId,
    String? firstName,
    String? lastName,
    String? headline,
    int? gradYear,
    String? city,
    String? avatarUrl,
    DateTime? createdAt,
  }) {
    return Profile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      headline: headline ?? this.headline,
      gradYear: gradYear ?? this.gradYear,
      city: city ?? this.city,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
