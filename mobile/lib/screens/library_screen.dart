import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'account_screen.dart';

/// My Library: bookmarks, favourites, reading history and what the user owns.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  Future<LibraryData>? _future;
  bool _wasSignedIn = false;

  void _load() => _future = context.read<AppState>().api.library();

  @override
  Widget build(BuildContext context) {
    final signedIn = context.watch<AppState>().isSignedIn;
    if (signedIn && (!_wasSignedIn || _future == null)) _load();
    _wasSignedIn = signedIn;

    if (!signedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Maktaba Yangu')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.local_library_outlined, size: 48),
              const SizedBox(height: 12),
              const Text('Ingia ili kuhifadhi jumbe, kuona historia yako na kuendelea ulipoishia.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen())),
                child: const Text('Ingia au jisajili'),
              ),
            ]),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Maktaba Yangu'),
          bottom: const TabBar(isScrollable: true, tabs: [
            Tab(text: 'Historia'),
            Tab(text: 'Alamisho'),
            Tab(text: 'Pendwa'),
            Tab(text: 'Nilivyonunua'),
          ]),
        ),
        body: FutureBuilder<LibraryData>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) return ErrorRetry(message: snap.error.toString(), onRetry: () => setState(_load));
            final lib = snap.data!;
            Widget list(List<ContentCard> items, String empty) => RefreshIndicator(
                  onRefresh: () async {
                    setState(_load);
                    await _future;
                  },
                  child: items.isEmpty
                      ? ListView(children: [EmptyState(icon: Icons.inbox, message: empty)])
                      : ListView(children: [for (final i in items) ContentTile(item: i)]),
                );
            return TabBarView(children: [
              list(lib.history.map((h) => h.content).toList(), 'Ukianza kusoma, historia itaonekana hapa.'),
              list(lib.bookmarks, 'Bado hujaweka alamisho.'),
              list(lib.favourites, 'Bado huna jumbe pendwa.'),
              list(lib.owned, 'Vitabu na rasilimali ulizonunua vitaonekana hapa.'),
            ]);
          },
        ),
      ),
    );
  }
}
