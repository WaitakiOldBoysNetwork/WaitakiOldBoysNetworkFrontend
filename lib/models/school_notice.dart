class SchoolNotice {
  final String id;
  final String title;
  final String snippet;
  final String badge;
  final String url;
  final String? imageUrl;
  final DateTime? publishedAt;

  const SchoolNotice({
    required this.id,
    required this.title,
    required this.snippet,
    required this.badge,
    required this.url,
    this.imageUrl,
    this.publishedAt,
  });

  factory SchoolNotice.fromJson(Map<String, dynamic> json) {
    return SchoolNotice(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      snippet: json['snippet']?.toString() ?? '',
      badge: json['badge']?.toString() ?? 'Hail Article',
      url: json['url']?.toString() ?? 'https://hail.to/waitaki-boys-high-school',
      imageUrl: json['image_url']?.toString(),
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'snippet': snippet,
      'badge': badge,
      'url': url,
      if (imageUrl != null) 'image_url': imageUrl,
      if (publishedAt != null) 'published_at': publishedAt!.toIso8601String(),
    };
  }

  /// Default verified WBHS Hail.to publications & articles for instant out-of-the-box display
  static const List<SchoolNotice> defaultNotices = [
    SchoolNotice(
      id: 'hail-newsletter-13',
      title: 'Newsletter #13 (2026)',
      snippet:
          'Latest WBHS term updates, academic excellence, winter sports fixtures, and rector’s report.',
      badge: 'Hail Newsletter',
      url: 'https://hail.to/waitaki-boys-high-school/publication/gsYrDVH',
      imageUrl:
          'https://assets.hail-cdn.com/uploads/500-constrained-e8a27443-f8aa-4d8e-a719-c2127b8208a4',
    ),
    SchoolNotice(
      id: 'hail-fraser-farm',
      title: 'WBHS Fraser Farm Updates',
      snippet:
          'Student agricultural practicals, farming skills, shearing, and local agribusiness partnerships.',
      badge: 'Hail Article',
      url: 'https://hail.to/waitaki-boys-high-school/article/43KIcVB',
      imageUrl:
          'https://assets.hail-cdn.com/uploads/500-constrained-14ab2602-0fa6-4e9e-aa97-1a4e7690ec84',
    ),
    SchoolNotice(
      id: 'hail-leavers-dinner',
      title: 'Senior Leavers\' Dinner & Notices',
      snippet:
          'End-of-year milestone celebrations, Hall of Memories traditions, and valedictory awards.',
      badge: 'Hail Notice',
      url: 'https://hail.to/waitaki-boys-high-school/article/kBz9veK',
      imageUrl:
          'https://assets.hail-cdn.com/uploads/500-constrained-b194435d-f137-4549-bd61-d8bd17deadf7',
    ),
  ];
}
