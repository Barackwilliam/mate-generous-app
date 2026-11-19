// Plain data classes for what the API returns. Unknown fields are ignored so
// the backend can add fields without breaking old app versions.

String? _s(dynamic v) => v?.toString();

class Ref {
  Ref({required this.slug, required this.title});
  final String slug;
  final String title;

  static Ref? fromJson(dynamic j) => j == null
      ? null
      : Ref(slug: j['slug'] ?? '', title: (j['title'] ?? j['name'] ?? '').toString());
}

class Category {
  Category({required this.id, required this.name, required this.slug, this.description = '', this.icon = '', this.isFlagship = false, this.coverImage});
  final int id;
  final String name;
  final String slug;
  final String description;
  final String icon;
  final bool isFlagship;
  final String? coverImage;

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'],
        name: j['name'] ?? '',
        slug: j['slug'] ?? '',
        description: j['description'] ?? '',
        icon: j['icon'] ?? '',
        isFlagship: j['is_flagship'] == true,
        coverImage: _s(j['cover_image']),
      );
}

class SeriesInfo {
  SeriesInfo({required this.id, required this.title, required this.slug, this.description = '', this.coverImage, this.itemCount, this.categoryName = ''});
  final int id;
  final String title;
  final String slug;
  final String description;
  final String? coverImage;
  final int? itemCount;
  final String categoryName;

  factory SeriesInfo.fromJson(Map<String, dynamic> j) => SeriesInfo(
        id: j['id'],
        title: j['title'] ?? '',
        slug: j['slug'] ?? '',
        description: j['description'] ?? '',
        coverImage: _s(j['cover_image']),
        itemCount: j['item_count'],
        categoryName: j['category']?['name'] ?? '',
      );
}

class ContentCard {
  ContentCard({
    required this.id,
    required this.slug,
    required this.title,
    required this.categoryName,
    this.seriesTitle,
    this.authorName,
    this.coverImage,
    this.scriptureReference = '',
    this.summary = '',
    this.hasAudio = false,
    this.isLocked = false,
    this.accessLevel = 'free',
  });

  final int id;
  final String slug;
  final String title;
  final String categoryName;
  final String? seriesTitle;
  final String? authorName;
  final String? coverImage;
  final String scriptureReference;
  final String summary;
  final bool hasAudio;
  final bool isLocked;
  final String accessLevel;

  factory ContentCard.fromJson(Map<String, dynamic> j) => ContentCard(
        id: j['id'],
        slug: j['slug'] ?? '',
        title: j['title'] ?? '',
        categoryName: j['category']?['name'] ?? '',
        seriesTitle: j['series']?['title'],
        authorName: j['author']?['name'],
        coverImage: _s(j['cover_image']),
        scriptureReference: j['scripture_reference'] ?? '',
        summary: j['summary'] ?? '',
        hasAudio: j['has_audio'] == true,
        isLocked: j['is_locked'] == true,
        accessLevel: j['access_level'] ?? 'free',
      );
}

class ContentDetail extends ContentCard {
  ContentDetail({
    required super.id,
    required super.slug,
    required super.title,
    required super.categoryName,
    super.seriesTitle,
    super.authorName,
    super.coverImage,
    super.scriptureReference,
    super.summary,
    super.hasAudio,
    super.isLocked,
    super.accessLevel,
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
  });

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

  factory ContentDetail.fromJson(Map<String, dynamic> j) {
    final card = ContentCard.fromJson(j);
    final state = j['user_state'] as Map<String, dynamic>?;
    return ContentDetail(
      id: card.id,
      slug: card.slug,
      title: card.title,
      categoryName: card.categoryName,
      seriesTitle: card.seriesTitle,
      authorName: card.authorName,
      coverImage: card.coverImage,
      scriptureReference: card.scriptureReference,
      summary: card.summary,
      hasAudio: card.hasAudio,
      isLocked: card.isLocked,
      accessLevel: card.accessLevel,
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
  LibraryData({required this.bookmarks, required this.favourites, required this.owned, required this.history});
  final List<ContentCard> bookmarks;
  final List<ContentCard> favourites;
  final List<ContentCard> owned;
  final List<HistoryEntry> history;

  factory LibraryData.fromJson(Map<String, dynamic> j) {
    List<ContentCard> cards(String key) => ((j[key] ?? []) as List).map((e) => ContentCard.fromJson(e)).toList();
    return LibraryData(
      bookmarks: cards('bookmarks'),
      favourites: cards('favourites'),
      owned: cards('owned_items'),
      history: ((j['history'] ?? []) as List)
          .map((e) => HistoryEntry(
                content: ContentCard.fromJson(e['content']),
                percent: e['percent'] ?? 0,
                completed: e['completed'] == true,
              ))
          .toList(),
    );
  }
}
