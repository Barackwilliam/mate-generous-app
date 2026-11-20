// Plain data classes for what the API returns. Unknown fields are ignored so
// the backend can add fields without breaking old app versions.

import 'dart:ui' show Color;

String? _s(dynamic v) => v?.toString();

Color parseHex(String? hex, Color fallback) {
  if (hex == null || hex.length != 7 || !hex.startsWith('#')) return fallback;
  final v = int.tryParse(hex.substring(1), radix: 16);
  return v == null ? fallback : Color(0xFF000000 | v);
}

class Ref {
  Ref({required this.slug, required this.title});
  final String slug;
  final String title;

  static Ref? fromJson(dynamic j) =>
      j == null ? null : Ref(slug: j['slug'] ?? '', title: (j['title'] ?? j['name'] ?? '').toString());
}

/// A category as shown on cards: enough to colour and label them.
class CategoryRef {
  CategoryRef({required this.slug, required this.name, this.nameEn = '', this.icon = '', this.accentHex});
  final String slug;
  final String name;
  final String nameEn;
  final String icon;
  final String? accentHex;

  String label(bool english) => english && nameEn.isNotEmpty ? nameEn : name;

  factory CategoryRef.fromJson(dynamic j) => CategoryRef(
        slug: j?['slug'] ?? '',
        name: j?['name'] ?? '',
        nameEn: j?['name_en'] ?? '',
        icon: j?['icon'] ?? '',
        accentHex: j?['accent_color'],
      );
}

class Category extends CategoryRef {
  Category({
    required this.id,
    required super.name,
    required super.slug,
    super.nameEn,
    super.icon,
    super.accentHex,
    this.description = '',
    this.descriptionEn = '',
    this.isFlagship = false,
    this.coverImage,
  });
  final int id;
  final String description;
  final String descriptionEn;
  final bool isFlagship;
  final String? coverImage;

  String about(bool english) => english && descriptionEn.isNotEmpty ? descriptionEn : description;

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'],
        name: j['name'] ?? '',
        nameEn: j['name_en'] ?? '',
        slug: j['slug'] ?? '',
        description: j['description'] ?? '',
        descriptionEn: j['description_en'] ?? '',
        icon: j['icon'] ?? '',
        accentHex: j['accent_color'],
        isFlagship: j['is_flagship'] == true,
        coverImage: _s(j['cover_image']),
      );
}

class Topic {
  Topic({required this.name, required this.slug});
  final String name;
  final String slug;
  factory Topic.fromJson(Map<String, dynamic> j) => Topic(name: j['name'] ?? '', slug: j['slug'] ?? '');
}

class SeriesInfo {
  SeriesInfo({required this.id, required this.title, required this.slug, required this.category, this.description = '', this.coverImage, this.itemCount});
  final int id;
  final String title;
  final String slug;
  final CategoryRef category;
  final String description;
  final String? coverImage;
  final int? itemCount;

  factory SeriesInfo.fromJson(Map<String, dynamic> j) => SeriesInfo(
        id: j['id'],
        title: j['title'] ?? '',
        slug: j['slug'] ?? '',
        category: CategoryRef.fromJson(j['category']),
        description: j['description'] ?? '',
        coverImage: _s(j['cover_image']),
        itemCount: j['item_count'],
      );
}

class ContentCard {
  ContentCard({
    required this.id,
    required this.slug,
    required this.title,
    required this.category,
    this.kind = 'devotional',
    this.seriesTitle,
    this.authorName,
    this.coverImage,
    this.scriptureReference = '',
    this.summary = '',
    this.hasAudio = false,
    this.audioSeconds,
    this.isLocked = false,
    this.accessLevel = 'free',
    this.readMinutes,
    this.publishAt,
  });

  final int id;
  final String slug;
  final String title;
  final CategoryRef category;
  final String kind;
  final String? seriesTitle;
  final String? authorName;
  final String? coverImage;
  final String scriptureReference;
  final String summary;
  final bool hasAudio;
  final int? audioSeconds;
  final bool isLocked;
  final String accessLevel;
  final int? readMinutes;
  final DateTime? publishAt;

  String? get audioLength {
    final s = audioSeconds;
    if (s == null) return null;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  factory ContentCard.fromJson(Map<String, dynamic> j) => ContentCard(
        id: j['id'],
        slug: j['slug'] ?? '',
        title: j['title'] ?? '',
        category: CategoryRef.fromJson(j['category']),
        kind: j['kind'] ?? 'devotional',
        seriesTitle: j['series']?['title'],
        authorName: j['author']?['name'],
        coverImage: _s(j['cover_image']),
        scriptureReference: j['scripture_reference'] ?? '',
        summary: j['summary'] ?? '',
        hasAudio: j['has_audio'] == true,
        audioSeconds: j['audio_duration_seconds'],
        isLocked: j['is_locked'] == true,
        accessLevel: j['access_level'] ?? 'free',
        readMinutes: j['read_minutes'],
        publishAt: DateTime.tryParse(j['publish_at']?.toString() ?? '')?.toLocal(),
      );
}

class ContentDetail extends ContentCard {
  ContentDetail({
    required ContentCard card,
    this.scriptureText = '',
    this.body,
    this.application,
    this.prayer,
    this.preview,
    this.previous,
    this.next,
    this.shareExcerpt = '',
    this.shareUrl = '',
    this.isBookmarked = false,
    this.isFavourite = false,
    this.audioPosition = 0,
  }) : super(
          id: card.id,
          slug: card.slug,
          title: card.title,
          category: card.category,
          kind: card.kind,
          seriesTitle: card.seriesTitle,
          authorName: card.authorName,
          coverImage: card.coverImage,
          scriptureReference: card.scriptureReference,
          summary: card.summary,
          hasAudio: card.hasAudio,
          audioSeconds: card.audioSeconds,
          isLocked: card.isLocked,
          accessLevel: card.accessLevel,
          readMinutes: card.readMinutes,
          publishAt: card.publishAt,
        );

  final String scriptureText;
  final String? body;
  final String? application;
  final String? prayer;
  final String? preview;
  final Ref? previous;
  final Ref? next;
  final String shareExcerpt;
  final String shareUrl;
  bool isBookmarked;
  bool isFavourite;
  final int audioPosition;

  factory ContentDetail.fromJson(Map<String, dynamic> j) {
    final state = j['user_state'] as Map<String, dynamic>?;
    return ContentDetail(
      card: ContentCard.fromJson(j),
      scriptureText: j['scripture_text'] ?? '',
      body: j['body'],
      application: j['application'],
      prayer: j['prayer'],
      preview: j['preview'],
      previous: Ref.fromJson(j['navigation']?['previous']),
      next: Ref.fromJson(j['navigation']?['next']),
      shareExcerpt: j['share']?['excerpt'] ?? '',
      shareUrl: j['share']?['url'] ?? '',
      isBookmarked: state?['is_bookmarked'] == true,
      isFavourite: state?['is_favourite'] == true,
      audioPosition: state?['audio_position_seconds'] ?? 0,
    );
  }
}

class HomeSection {
  HomeSection({required this.title, required this.kind, this.items = const [], this.series = const [], this.categorySlug});
  final String title;
  final String kind;
  final List<ContentCard> items;
  final List<SeriesInfo> series;
  final String? categorySlug;

  factory HomeSection.fromJson(Map<String, dynamic> j) => HomeSection(
        title: j['title'] ?? '',
        kind: j['kind'] ?? '',
        items: ((j['items'] ?? []) as List).map((e) => ContentCard.fromJson(e)).toList(),
        series: ((j['series'] ?? []) as List).map((e) => SeriesInfo.fromJson(e)).toList(),
        categorySlug: j['category']?['slug'],
      );
}

class HomeData {
  HomeData({this.tonight, required this.sections});
  final ContentDetail? tonight;
  final List<HomeSection> sections;

  factory HomeData.fromJson(Map<String, dynamic> j) => HomeData(
        tonight: j['tonight'] == null ? null : ContentDetail.fromJson(j['tonight']),
        sections: ((j['sections'] ?? []) as List).map((e) => HomeSection.fromJson(e)).toList(),
      );
}

class AppUser {
  AppUser({required this.email, required this.fullName, this.phone});
  final String email;
  final String fullName;
  final String? phone;

  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }

  factory AppUser.fromJson(Map<String, dynamic> j) =>
      AppUser(email: j['email'] ?? '', fullName: j['full_name'] ?? '', phone: j['phone']);
}

class HistoryEntry {
  HistoryEntry({required this.content, required this.percent, required this.completed});
  final ContentCard content;
  final int percent;
  final bool completed;
}

class LibraryData {
  LibraryData({
    required this.bookmarks,
    required this.favourites,
    required this.owned,
    required this.ownedSeries,
    required this.history,
    this.streak = 0,
    this.completedCount = 0,
    this.savedCount = 0,
  });
  final List<ContentCard> bookmarks;
  final List<ContentCard> favourites;
  final List<ContentCard> owned;
  final List<SeriesInfo> ownedSeries;
  final List<HistoryEntry> history;
  final int streak;
  final int completedCount;
  final int savedCount;

  factory LibraryData.fromJson(Map<String, dynamic> j) {
    List<ContentCard> cards(String key) => ((j[key] ?? []) as List).map((e) => ContentCard.fromJson(e)).toList();
    final stats = j['stats'] as Map<String, dynamic>? ?? const {};
    return LibraryData(
      bookmarks: cards('bookmarks'),
      favourites: cards('favourites'),
      owned: cards('owned_items'),
      ownedSeries: ((j['owned_series'] ?? []) as List).map((e) => SeriesInfo.fromJson(e)).toList(),
      history: ((j['history'] ?? []) as List)
          .map((e) => HistoryEntry(
                content: ContentCard.fromJson(e['content']),
                percent: e['percent'] ?? 0,
                completed: e['completed'] == true,
              ))
          .toList(),
      streak: stats['streak_days'] ?? 0,
      completedCount: stats['completed'] ?? 0,
      savedCount: stats['saved'] ?? 0,
    );
  }
}

class Plan {
  Plan({required this.id, required this.name, required this.tier, required this.days, required this.price});
  final int id;
  final String name;
  final String tier;
  final int days;
  final num price;

  factory Plan.fromJson(Map<String, dynamic> j) => Plan(
        id: j['id'],
        name: j['name'] ?? '',
        tier: j['tier'] ?? 'standard',
        days: j['duration_days'] ?? 0,
        price: num.tryParse(j['price'].toString()) ?? 0,
      );
}

class Access {
  Access({this.tier, this.expiresAt, this.planName});
  final String? tier; // null = free
  final DateTime? expiresAt;
  final String? planName;

  factory Access.fromJson(Map<String, dynamic> j) {
    final history = (j['history'] as List? ?? const []);
    final current = history.cast<Map<String, dynamic>>().where((h) => h['is_current'] == true).toList();
    return Access(
      tier: j['tier'],
      expiresAt: DateTime.tryParse(j['expires_at']?.toString() ?? '')?.toLocal(),
      planName: current.isEmpty ? null : current.first['plan']?['name'],
    );
  }
}
