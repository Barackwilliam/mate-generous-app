import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/common.dart';
import '../widgets/live.dart';
import '../widgets/shell.dart';
import 'category_screen.dart';
import 'search_screen.dart';

/// Every department the admin has published, as the template's grid of
/// glossy tiles, in the admin's order.
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  Future<(List<Category>, List<Topic>)> _load(BuildContext context) async {
    final api = context.read<AppState>().api;
    final r = await Future.wait([api.categories(), api.topics().catchError((_) => <Topic>[])]);
    return (r[0] as List<Category>, r[1] as List<Topic>);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final p = context.pal;
    return Scaffold(
      body: NightBackground(
        child: SafeArea(
          bottom: false,
          child: LiveData<(List<Category>, List<Topic>)>(
            load: () => _load(context),
            builder: (context, data, reload) {
              final (cats, topics) = data;
              return RefreshIndicator(
                color: p.accent,
                onRefresh: reload,
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 120), children: [
                  const AppTopBar(),
                  const SizedBox(height: 6),
                  Text(s.discover, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  const SizedBox(height: 14),
                  _SearchField(hint: s.searchContent, onTap: () => push(context, const SearchScreen())),
                  if (topics.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final t in topics.take(6))
                        SelectChip(label: t.name, selected: false, onTap: () => push(context, SearchScreen(topic: t))),
                    ]),
                  ],
                  const SizedBox(height: 18),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.92,
                    children: [
                      for (final c in cats)
                        DeptTile(category: c, label: c.label(s.en), onTap: () => push(context, CategoryScreen.forCategory(c))),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SecondaryButton(
                    gold: true,
                    label: s.exploreMore,
                    trailing: const Icon(Icons.arrow_forward_rounded, size: 20),
                    onPressed: () => push(context, const SearchScreen()),
                  ),
                ]),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.hint, required this.onTap});
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      button: true,
      label: hint,
      child: Material(
        color: p.surface,
        shape: StadiumBorder(side: BorderSide(color: p.border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: SizedBox(
            height: 50,
            child: Row(children: [
              const SizedBox(width: 16),
              Icon(Icons.search_rounded, color: p.muted, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(hint, style: TextStyle(color: p.faint, fontSize: 15), overflow: TextOverflow.ellipsis)),
            ]),
          ),
        ),
      ),
    );
  }
}
