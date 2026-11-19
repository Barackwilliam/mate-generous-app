import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

/// Search by title, Scripture, keyword, series, topic or author.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  Future<List<ContentCard>>? _results;

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() => _results = q.trim().length < 2 ? null : context.read<AppState>().api.contents(query: q.trim()));
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Tafuta kichwa, andiko, mada, mwandishi…',
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search),
          ),
        ),
      ),
      body: _results == null
          ? const EmptyState(icon: Icons.search, message: 'Andika angalau herufi mbili. Mfano: “Zaburi 23” au “msamaha”.')
          : FutureBuilder<List<ContentCard>>(
              future: _results,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                if (snap.hasError) return ErrorRetry(message: snap.error.toString(), onRetry: () => _onChanged(_controller.text));
                if (snap.data!.isEmpty) return const EmptyState(icon: Icons.search_off, message: 'Hakuna kilichopatikana.');
                return ListView(children: [for (final item in snap.data!) ContentTile(item: item)]);
              },
            ),
    );
  }
}
