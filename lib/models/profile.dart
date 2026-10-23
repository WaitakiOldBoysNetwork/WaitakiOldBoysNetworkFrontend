class Profile {
  final String id;
  final String? userId;
  final String? firstName;
  final String? lastName;
  final String? headline;
  final int? gradYear;
  final String? city;
  final String? avatarUrl;
  final String? bannerUrl;
  final String? house;
  final String? industry;
  final String? company;
  final String? bio;
  final String? email;
  final String? phone;
  final String? openToHelping;
  final String? lookingFor;
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
    this.bannerUrl,
    this.house,
    this.industry,
    this.company,
    this.bio,
    this.email,
    this.phone,
    this.openToHelping,
    this.lookingFor,
    this.createdAt,
  });

  String get fullName {
    final first = (firstName ?? '').trim();
    final last = (lastName ?? '').trim();
    if (first.isEmpty && last.isEmpty) return 'Old Boy';
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
    if (result.isEmpty) return 'OB';
    return result;
  }

  /// Generates a standardized placeholder avatar image URL featuring user initials
  /// on a WBHS Navy (#0F2547) background with Heritage Gold (#D4AF37) bold text.
  static String generatePlaceholderAvatar({
    String? firstName,
    String? lastName,
    String? initials,
  }) {
    String inits = (initials ?? '').trim().toUpperCase();
    if (inits.isEmpty) {
      final first = (firstName ?? '').trim();
      final last = (lastName ?? '').trim();
      if (first.isNotEmpty) inits += first[0].toUpperCase();
      if (last.isNotEmpty) inits += last[0].toUpperCase();
    }
    if (inits.isEmpty) inits = 'OB';

    return 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(inits)}&background=0F2547&color=D4AF37&bold=true&size=256';
  }

  /// Always returns a valid avatar image URL, falling back to the initials placeholder
  String get effectiveAvatarUrl {
    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      return avatarUrl!;
    }
    return generatePlaceholderAvatar(
      firstName: firstName,
      lastName: lastName,
      initials: initials,
    );
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    String? fName = json['first_name']?.toString();
    String? lName = json['last_name']?.toString();

    // Fallback if imported record has combined 'Name'
    if ((fName == null || fName.trim().isEmpty) &&
        (lName == null || lName.trim().isEmpty) &&
        json['Name'] != null) {
      final nameStr = json['Name'].toString().trim();
      final parts = nameStr.split(RegExp(r'\s+'));
      if (parts.isNotEmpty) {
        fName = parts.first;
        if (parts.length > 1) {
          lName = parts.sublist(1).join(' ');
        }
      }
    }

    final grad = json['grad_year'] != null
        ? int.tryParse(json['grad_year'].toString())
        : (json['Year left School'] != null
            ? int.tryParse(json['Year left School'].toString())
            : null);

    final rawCity = json['city']?.toString();
    final cityVal = (rawCity != null && rawCity.isNotEmpty)
        ? rawCity
        : json['Region']?.toString();

    final rawHeadline = json['headline']?.toString();
    final headlineVal = (rawHeadline != null && rawHeadline.isNotEmpty)
        ? rawHeadline
        : json['What are you up to']?.toString();

    // Parse avatar URL from avatar_url or Airtable Profile Photo format
    String? photoUrl = json['avatar_url']?.toString();
    if (photoUrl == null || photoUrl.isEmpty) {
      final rawPhoto = json['Profile Photo']?.toString();
      if (rawPhoto != null && rawPhoto.isNotEmpty) {
        final match = RegExp(r'https?://[^\s)]+').firstMatch(rawPhoto);
        if (match != null) {
          photoUrl = match.group(0);
        }
      }
    }

    // Default to initials placeholder image if no custom photo uploaded
    if (photoUrl == null || photoUrl.isEmpty) {
      photoUrl = Profile.generatePlaceholderAvatar(
        firstName: fName,
        lastName: lName,
      );
    }

    // Parse banner URL from banner_url or Airtable Banner Photo format
    String? bannerPhotoUrl = json['banner_url']?.toString();
    if (bannerPhotoUrl == null || bannerPhotoUrl.isEmpty) {
      final rawBanner = json['Banner Photo']?.toString() ?? json['banner']?.toString();
      if (rawBanner != null && rawBanner.isNotEmpty) {
        final match = RegExp(r'https?://[^\s)]+').firstMatch(rawBanner);
        if (match != null) {
          bannerPhotoUrl = match.group(0);
        } else if (rawBanner.startsWith('http')) {
          bannerPhotoUrl = rawBanner;
        }
      }
    }

    final rawId = (json['id'] ?? json['user_id'] ?? json['Email'] ?? json['Name'] ?? '').toString().trim();
    final idVal = rawId.isNotEmpty ? rawId : DateTime.now().microsecondsSinceEpoch.toString();

    return Profile(
      id: idVal,
      userId: json['user_id']?.toString(),
      firstName: fName,
      lastName: lName,
      headline: headlineVal,
      gradYear: grad,
      city: cityVal,
      avatarUrl: photoUrl,
      bannerUrl: bannerPhotoUrl,
      house: json['house']?.toString() ?? json['House']?.toString(),
      industry: json['industry']?.toString() ?? json['Industry']?.toString(),
      company: json['company']?.toString() ?? json['Company / Organisation']?.toString(),
      bio: json['bio']?.toString() ?? json['Short Bio']?.toString() ?? json['Full Bio']?.toString(),
      email: json['email']?.toString() ?? json['Email']?.toString().trim(),
      phone: json['phone']?.toString() ?? json['Phone']?.toString(),
      openToHelping: json['open_to_helping']?.toString() ?? json['Open to helping']?.toString(),
      lookingFor: json['looking_for']?.toString() ?? json['Looking for']?.toString(),
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
      if (bannerUrl != null) 'banner_url': bannerUrl,
      if (bio != null) 'bio': bio,
      if (house != null) ...{'house': house, 'House': house},
      if (industry != null) ...{'industry': industry, 'Industry': industry},
      if (company != null) ...{'company': company, 'Company / Organisation': company},
      if (openToHelping != null) ...{'open_to_helping': openToHelping, 'Open to helping': openToHelping},
      if (lookingFor != null) ...{'looking_for': lookingFor, 'Looking for': lookingFor},
      if (email != null) 'Email': email,
      if (phone != null) 'Phone': phone,
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
    String? bannerUrl,
    String? house,
    String? industry,
    String? company,
    String? bio,
    String? email,
    String? phone,
    String? openToHelping,
    String? lookingFor,
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
      bannerUrl: bannerUrl ?? this.bannerUrl,
      house: house ?? this.house,
      industry: industry ?? this.industry,
      company: company ?? this.company,
      bio: bio ?? this.bio,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      openToHelping: openToHelping ?? this.openToHelping,
      lookingFor: lookingFor ?? this.lookingFor,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
