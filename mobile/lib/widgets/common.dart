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

bool isOffline(Object e) => e is ApiException && (e.message == 'offline' || e.message == 'slow');

void openReader(BuildContext context, String slug) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReaderScreen(slug: slug)));
}

void push(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

/// The dark night background used behind screens.
class NightBackground extends StatelessWidget {
  const NightBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = identical(context.pal, Palette.dark);
    return DecoratedBox(
      decoration: BoxDecoration(gradient: dark ? Palette.nightGradient : null, color: dark ? null : context.pal.bg),
      child: child,
    );
  }
}

/// The SW | EN switch shown on every screen.
class LangToggle extends StatelessWidget {
  const LangToggle({super.key, this.onImage = false, this.compact = false, this.small = false});
  final bool onImage;

  /// A smaller switch, for the menu and the sign-in page.
  final bool small;

  /// Plain "SW | EN" text, as in the reader's toolbar.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final app = context.watch<AppState>();
    if (compact) {
      TextSpan part(String code) => TextSpan(
            text: code.toUpperCase(),
            style: TextStyle(fontWeight: app.lang == code ? FontWeight.w800 : FontWeight.w600, color: app.lang == code ? p.text : p.faint),
          );
      return Semantics(
        button: true,
        label: app.lang == 'sw' ? 'Switch to English' : 'Badili kwenda Kiswahili',
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => app.setLang(app.lang == 'sw' ? 'en' : 'sw'),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            child: Text.rich(TextSpan(children: [part('sw'), TextSpan(text: ' | ', style: TextStyle(color: p.faint)), part('en')]),
                style: const TextStyle(fontSize: 13)),
          ),
        ),
      );
    }
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
            height: small ? 26 : 34,
            constraints: BoxConstraints(minWidth: small ? 34 : 40),
            padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(gradient: on ? Palette.goldGradient : null, borderRadius: BorderRadius.circular(17)),
            child: Text(code.toUpperCase(),
                style: TextStyle(fontSize: small ? 11 : 12, fontWeight: on ? FontWeight.w800 : FontWeight.w700, color: on ? p.onAccent : (onImage ? Colors.white : p.muted))),
          ),
        ),
      );
    }

    return Container(
      height: small ? 34 : 44,
      padding: EdgeInsets.all(small ? 3 : 4),
      decoration: BoxDecoration(
        color: onImage ? Palette.night.withValues(alpha: 0.55) : p.surface,
        borderRadius: BorderRadius.circular(small ? 17 : 22),
        border: Border.all(color: onImage ? Colors.white24 : p.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [option('sw'), const SizedBox(width: 2), option('en')]),
    );
  }
}

class RoundButton extends StatelessWidget {
  const RoundButton({super.key, required this.icon, required this.label, required this.onTap, this.filled = false, this.onImage = false, this.bare = false});
  final Widget icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final bool onImage;

  /// No circle behind the icon (toolbar style).
  final bool bare;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final bg = bare ? Colors.transparent : (filled ? p.accent : (onImage ? Palette.night.withValues(alpha: 0.55) : p.surface));
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: bg,
          shape: CircleBorder(side: bare || filled || onImage ? BorderSide.none : BorderSide(color: p.border)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: IconTheme(
                data: IconThemeData(color: filled ? p.onAccent : (onImage ? Colors.white : p.text), size: 22),
                child: Center(child: icon),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The template's gold pill button.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.icon, this.trailing, this.busy = false, this.height = 54, this.color});
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final Widget? trailing;
  final bool busy;
  final double height;

  /// Solid colour instead of gold (e.g. the green "Jaribu tena").
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final enabled = onPressed != null && !busy;
    final fg = color != null ? Colors.white : p.onAccent;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Opacity(
        opacity: onPressed == null ? 0.55 : 1,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            gradient: color == null ? Palette.goldGradient : null,
            color: color,
            borderRadius: BorderRadius.circular(height / 2),
            boxShadow: [
              if (enabled && color == null) BoxShadow(color: Palette.gold.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(height / 2),
              onTap: enabled ? onPressed : null,
              child: Center(
                child: busy
                    ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: IconTheme(
                          data: IconThemeData(color: fg, size: 20),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (icon != null) ...[icon!, const SizedBox(width: 8)],
                            Flexible(
                              child: Text(label,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontFamily: AppTheme.sans, fontSize: 16, fontWeight: FontWeight.w800, color: fg)),
                            ),
                            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
                          ]),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Outlined pill (white or gold border).
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, required this.onPressed, this.icon, this.trailing, this.height = 52, this.gold = false, this.solidWhite = false});
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final Widget? trailing;
  final double height;
  final bool gold;
  final bool solidWhite;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final fg = solidWhite ? const Color(0xFF1A1033) : (gold ? p.accentText : p.text);
    return SizedBox(
      height: height,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: solidWhite ? Colors.white : Colors.transparent,
          foregroundColor: fg,
          side: BorderSide(color: solidWhite ? Colors.white : (gold ? p.accent : p.text.withValues(alpha: 0.7)), width: 1.4),
          shape: StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          textStyle: const TextStyle(fontFamily: AppTheme.sans, fontSize: 15, fontWeight: FontWeight.w700),
        ),
        onPressed: onPressed,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[icon!, const SizedBox(width: 8)],
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
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
        padding: const EdgeInsets.fromLTRB(20, 24, 10, 8),
        child: Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: context.pal.accentText, minimumSize: const Size(44, 44)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(action!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded, size: 16),
              ]),
            ),
        ]),
      );
}

class SelectChip extends StatelessWidget {
  const SelectChip({super.key, required this.label, required this.selected, required this.onTap, this.accent = true});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: ShapeDecoration(
            gradient: selected ? Palette.goldGradient : null,
            color: selected ? null : p.surface,
            shape: StadiumBorder(side: selected ? BorderSide.none : BorderSide(color: p.border)),
          ),
          child: Text(label,
              style: TextStyle(fontSize: 13.5, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: selected ? p.onAccent : p.text)),
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

/// A rounded picture for an item: its cover, else its department's picture.
class ItemArt extends StatelessWidget {
  const ItemArt({super.key, required this.category, this.imageUrl, this.size = 56, this.radius = 14, this.width});
  final CategoryRef category;
  final String? imageUrl;
  final double size;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: AppImage(url: imageUrl, fallback: DeptLook.of(category).picture, width: width ?? size, height: size),
      );
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.item});
  final ContentCard item;

  @override
  Widget build(BuildContext context) => ItemArt(category: item.category, imageUrl: item.coverImage, size: 58, width: 67, radius: 12);
}

/// A row in a list: picture, title, scripture, and a chevron or marks.
class ContentRow extends StatelessWidget {
  const ContentRow({super.key, required this.item, this.trailing, this.subtitle});
  final ContentCard item;
  final Widget? trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final s = context.s;
    final sub = subtitle ?? (item.scriptureReference.isNotEmpty ? item.scriptureReference : item.category.label(s.en));
    return InkWell(
      onTap: () => openReader(context, item.slug),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(children: [
          _Thumb(item: item),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: p.muted)),
            ]),
          ),
          const SizedBox(width: 8),
          trailing ??
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (item.isLocked) ...[
                  if (item.accessLevel == 'premium') const PremiumBadge() else Icon(Icons.lock_rounded, size: 18, color: p.muted),
                  const SizedBox(width: 4),
                ] else if (item.hasAudio) ...[
                  Icon(Icons.headphones_rounded, size: 18, color: p.muted, semanticLabel: s.audio),
                  const SizedBox(width: 4),
                ],
                Icon(Icons.chevron_right_rounded, color: p.muted),
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
        decoration: BoxDecoration(gradient: Palette.goldGradient, borderRadius: BorderRadius.circular(6)),
        child: Text('PREMIUM',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: context.pal.onAccent)),
      );
}

/// A card in a horizontal shelf: picture with the title over it.
class ContentShelfCard extends StatelessWidget {
  const ContentShelfCard({super.key, required this.item});
  final ContentCard item;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return SizedBox(
      width: 168,
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: p.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openReader(context, item.slug),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(children: [
              AppImage(url: item.coverImage, fallback: DeptLook.of(item.category).picture, height: 104, width: double.infinity),
              if (item.isLocked)
                Positioned(
                  top: 8,
                  right: 8,
                  child: item.accessLevel == 'premium'
                      ? const PremiumBadge()
                      : CircleAvatar(radius: 13, backgroundColor: Palette.night.withValues(alpha: 0.7), child: const Icon(Icons.lock_rounded, size: 14, color: Colors.white)),
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
}

/// A department tile from the template: vivid gradient, glossy icon, white name.
class DeptTile extends StatelessWidget {
  const DeptTile({super.key, required this.category, required this.label, required this.onTap});
  final CategoryRef category;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final look = DeptLook.of(category);
    return Semantics(
      button: true,
      label: label,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: look.colors),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          boxShadow: [BoxShadow(color: look.colors.last.withValues(alpha: 0.45), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
              child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Image.asset(look.iconPath, fit: BoxFit.contain)),
                const SizedBox(height: 6),
                Text(label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14.5, height: 1.15,
                        shadows: [Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 1))])),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// The template's state cards: a picture with a message and one action.
class StateCard extends StatelessWidget {
  const StateCard({super.key, required this.image, required this.title, this.subtitle, this.icon, this.action, this.onAction, this.light = true, this.busy = false});
  final String image;
  final String title;
  final String? subtitle;
  final Widget? icon;
  final String? action;
  final VoidCallback? onAction;
  final bool light;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final fg = light ? const Color(0xFF14162E) : Colors.white;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(children: [
          Positioned.fill(child: Image.asset(image, fit: BoxFit.cover)),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: light ? Colors.white.withValues(alpha: 0.72) : Palette.night.withValues(alpha: 0.45),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (busy)
                const Center(child: SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3, color: Palette.gold)))
              else if (icon != null)
                Center(child: IconTheme(data: IconThemeData(color: fg, size: 44), child: icon!)),
              const SizedBox(height: 14),
              Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: fg)),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(subtitle!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: fg.withValues(alpha: 0.85), height: 1.4)),
              ],
              if (action != null) ...[
                const SizedBox(height: 16),
                Center(child: SizedBox(width: 220, child: PrimaryButton(label: action!, onPressed: onAction, color: Palette.green, height: 46))),
              ],
            ]),
          ),
        ]),
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
      child: SingleChildScrollView(
        child: StateCard(
          image: Img.offline,
          icon: const Icon(Icons.wifi_off_rounded),
          title: isOffline(error) ? s.offline : errorText(s, error),
          action: s.retry,
          onAction: onRetry,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, this.title, this.icon, this.action, this.onAction});
  final String message;
  final String? title;
  final Widget? icon;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => StateCard(
        image: Img.empty,
        icon: icon ?? const Icon(Icons.menu_book_rounded),
        title: title ?? context.s.nothingYet,
        subtitle: message,
        action: action,
        onAction: onAction,
      );
}

class Loading extends StatelessWidget {
  const Loading({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          child: StateCard(image: Img.loading, light: false, busy: true, title: context.s.loadingTitle, subtitle: context.s.pleaseWait),
        ),
      );
}
