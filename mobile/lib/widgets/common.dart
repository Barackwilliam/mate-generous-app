import 'package:material_ui/material_ui.dart';

import '../api/models.dart';
import '../screens/reader_screen.dart';

class CoverImage extends StatelessWidget {
  const CoverImage({super.key, this.url, this.height, this.icon = Icons.menu_book});
  final String? url;
  final double? height;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      height: height,
      color: scheme.primaryContainer,
      alignment: Alignment.center,
      child: Icon(icon, color: scheme.onPrimaryContainer, size: 36),
    );
    if (url == null || url!.isEmpty) return placeholder;
    return Image.network(url!, height: height, width: double.infinity, fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder);
  }
}

void openReader(BuildContext context, String slug) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReaderScreen(slug: slug)));
}

class ContentTile extends StatelessWidget {
  const ContentTile({super.key, required this.item});
  final ContentCard item;

  @override
  Widget build(BuildContext context) {
    final subtitle = [item.scriptureReference, item.seriesTitle ?? item.categoryName].where((s) => s.isNotEmpty).join(' · ');
    return ListTile(
      onTap: () => openReader(context, item.slug),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(width: 56, height: 56, child: CoverImage(url: item.coverImage)),
      ),
      title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (item.hasAudio) const Icon(Icons.headphones, size: 18),
        if (item.isLocked) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.lock_outline, size: 18)),
      ]),
    );
  }
}

class ContentCardTile extends StatelessWidget {
  const ContentCardTile({super.key, required this.item});
  final ContentCard item;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: 180,
      child: Card(
        child: InkWell(
          onTap: () => openReader(context, item.slug),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(children: [
              CoverImage(url: item.coverImage, height: 100),
              if (item.isLocked)
                const Positioned(top: 6, right: 6, child: CircleAvatar(radius: 13, child: Icon(Icons.lock, size: 15))),
            ]),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleSmall),
                const SizedBox(height: 4),
                Text(item.scriptureReference.isNotEmpty ? item.scriptureReference : item.categoryName,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Jaribu tena')),
          ]),
        ),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 40, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ]),
        ),
      );
}
