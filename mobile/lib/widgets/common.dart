import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../i18n/strings.dart';
import '../screens/reader_screen.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import 'art.dart';

String errorText(S s, Object e) {
  final msg = e is ApiException ? e.message : e.toString();
  return switch (msg) { 'offline' => s.offline, 'slow' => s.slow, _ => msg };
}

void openReader(BuildContext context, String slug) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReaderScreen(slug: slug)));
}

void push(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

/// The SW | EN switch shown on every screen.
class LangToggle extends StatelessWidget {
  const LangToggle({super.key, this.onImage = false});
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final app = context.watch<AppState>();
    Widget option(String code) {
      final on = app.lang == code;
      return Semantics(
        button: true,
        selected: on,
        label: code == 'sw' ? 'Kiswahili' : 'English',
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: () => app.setLang(code),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 34,
            constraints: const BoxConstraints(minWidth: 40),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: on ? p.chipOn : Colors.transparent, borderRadius: BorderRadius.circular(17)),
            child: Text(code.toUpperCase(),
                style: TextStyle(fontSize: 12, fontWeight: on ? FontWeight.w800 : FontWeight.w700, color: on ? p.chipOnText : p.muted)),
          ),
        ),
      );
    }

    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: onImage ? Palette.night.withValues(alpha: 0.6) : p.surface,
        borderRadius: BorderRadius.circular(22),
        border: onImage ? null : Border.all(color: p.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [option('sw'), const SizedBox(width: 2), option('en')]),
    );
  }
}

class RoundButton extends StatelessWidget {
  const RoundButton({super.key, required this.icon, required this.label, required this.onTap, this.filled = false, this.onImage = false});
  final Widget icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: filled ? p.text : (onImage ? Palette.night.withValues(alpha: 0.6) : p.surface),
          shape: CircleBorder(side: filled || onImage ? BorderSide.none : BorderSide(color: p.border)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: IconTheme(
                data: IconThemeData(color: filled ? p.accent : (onImage ? Colors.white : p.text), size: 20),
                child: Center(child: icon),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.icon, this.busy = false, this.height = 56});
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool busy;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return SizedBox(
      height: height,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          disabledBackgroundColor: p.surfaceHi,
          disabledForegroundColor: p.muted,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontFamily: AppTheme.sans, fontSize: 16, fontWeight: FontWeight.w800),
        ),
        onPressed: busy ? null : onPressed,
        child: busy
            ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: p.onAccent))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[icon!, const SizedBox(width: 8)],
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              ]),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, required this.onPressed, this.icon, this.height = 54});
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return SizedBox(
      height: height,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: p.surface,
          foregroundColor: p.text,
          side: BorderSide(color: p.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontFamily: AppTheme.sans, fontSize: 15, fontWeight: FontWeight.w700),
        ),
        onPressed: onPressed,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[icon!, const SizedBox(width: 8)],
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 26, 12, 10),
        child: Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: context.pal.accentText, minimumSize: const Size(44, 44)),
              child: Text(action!, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
        ]),
      );
}

class SelectChip extends StatelessWidget {
  const SelectChip({super.key, required this.label, required this.selected, required this.onTap, this.accent = false});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final bg = selected ? (accent ? p.accent : p.chipOn) : p.surface;
    final fg = selected ? (accent ? p.onAccent : p.chipOnText) : p.text;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: bg,
        shape: StadiumBorder(side: selected ? BorderSide.none : BorderSide(color: p.border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(label, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w600, color: fg)),
          ),
        ),
      ),
    );
  }
}

class ThinProgress extends StatelessWidget {
  const ThinProgress({super.key, required this.value, this.color, this.height = 4});
  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(
          value: value.clamp(0, 1),
          minHeight: height,
          backgroundColor: context.pal.border,
          color: color ?? context.pal.accent,
        ),
      );
}

/// Square artwork for an item: its cover image, else its category's colour and icon.
class ItemArt extends StatelessWidget {
  const ItemArt({super.key, required this.category, this.imageUrl, this.size = 56, this.radius = 16});
  final CategoryRef category;
  final String? imageUrl;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final style = CategoryStyle.of(category);
    final fallback = Container(
      width: size,
      height: size,
      color: p.tint(style.accent),
      alignment: Alignment.center,
      child: style.icon(size: size * 0.42, color: p.onTint(style.accent)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: imageUrl == null || imageUrl!.isEmpty
          ? fallback
          : Image.network(imageUrl!, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
    );
  }
}

/// A row in a list: art, title, scripture/category, audio and lock marks.
class ContentRow extends StatelessWidget {
  const ContentRow({super.key, required this.item, this.trailing, this.subtitle});
  final ContentCard item;
  final Widget? trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final s = context.s;
    final sub = subtitle ??
        [item.seriesTitle ?? item.category.label(s.en), item.scriptureReference].where((x) => x.isNotEmpty).join(' · ');
    return InkWell(
      onTap: () => openReader(context, item.slug),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(children: [
          ItemArt(category: item.category, imageUrl: item.coverImage, size: 52, radius: 14),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.muted)),
            ]),
          ),
          const SizedBox(width: 8),
          trailing ??
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (item.hasAudio) Icon(Icons.headphones_rounded, size: 18, color: p.muted, semanticLabel: s.audio),
                if (item.isLocked) ...[
                  const SizedBox(width: 6),
                  if (item.accessLevel == 'premium') const PremiumBadge() else Icon(Icons.lock_outline_rounded, size: 18, color: p.muted),
                ],
              ]),
        ]),
      ),
    );
  }
}

class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: context.pal.accent, borderRadius: BorderRadius.circular(6)),
        child: Text('PREMIUM',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: context.pal.onAccent)),
      );
}

/// A card in a horizontal shelf.
class ContentShelfCard extends StatelessWidget {
  const ContentShelfCard({super.key, required this.item});
  final ContentCard item;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final style = CategoryStyle.of(item.category);
    return SizedBox(
      width: 172,
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: p.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openReader(context, item.slug),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(children: [
              item.coverImage != null
                  ? Image.network(item.coverImage!, height: 96, width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _tintBox(p, style))
                  : _tintBox(p, style),
              if (item.isLocked)
                Positioned(
                  top: 8,
                  right: 8,
                  child: item.accessLevel == 'premium'
                      ? const PremiumBadge()
                      : CircleAvatar(radius: 13, backgroundColor: p.bg, child: Icon(Icons.lock_rounded, size: 14, color: p.text)),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: AppTheme.serif, fontSize: 15, fontWeight: FontWeight.w600, height: 1.25)),
                const SizedBox(height: 4),
                Text(item.scriptureReference.isNotEmpty ? item.scriptureReference : item.category.label(context.s.en),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.muted)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _tintBox(Palette p, CategoryStyle style) => Container(
        height: 96,
        width: double.infinity,
        color: p.tint(style.accent),
        alignment: Alignment.center,
        child: style.icon(size: 34, color: p.onTint(style.accent)),
      );
}

/// A coloured tile for a series or a category.
class ColourTile extends StatelessWidget {
  const ColourTile({super.key, required this.title, required this.subtitle, required this.category, required this.onTap, this.width, this.height = 120, this.badge});
  final String title;
  final String subtitle;
  final CategoryRef category;
  final VoidCallback onTap;
  final double? width;
  final double height;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final style = CategoryStyle.of(category);
    final fg = p.onTint(style.accent);
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: p.tint(style.accent),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              style.icon(size: 26, color: style.accent == Palette.gold ? fg : style.accent),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: fg)),
                    if (subtitle.isNotEmpty)
                      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: fg.withValues(alpha: 0.8))),
                  ]),
                ),
                ?badge,
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_rounded, size: 40, color: context.pal.muted),
          const SizedBox(height: 12),
          Text(errorText(s, error), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          SecondaryButton(label: s.retry, onPressed: onRetry, height: 46),
        ]),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, this.icon});
  final String message;
  final Widget? icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          icon ?? CrossIcon(size: 34, color: context.pal.faint),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: context.pal.muted, height: 1.5)),
        ]),
      );
}

class Loading extends StatelessWidget {
  const Loading({super.key});

  @override
  Widget build(BuildContext context) =>
      Center(child: Padding(padding: const EdgeInsets.all(40), child: CircularProgressIndicator(color: context.pal.accent)));
}
