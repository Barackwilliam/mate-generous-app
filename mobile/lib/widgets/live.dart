import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'common.dart';

/// Shows data that loads offline-first: the saved copy appears at once, and
/// when the background refresh brings something newer the screen updates by
/// itself, without a spinner and without losing the scroll position.
class LiveData<T> extends StatefulWidget {
  const LiveData({super.key, required this.load, required this.builder, this.loading, this.watchKey});
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;
  final Widget? loading;

  /// Change this to load again (e.g. a new filter).
  final Object? watchKey;

  @override
  State<LiveData<T>> createState() => _LiveDataState<T>();
}

class _LiveDataState<T> extends State<LiveData<T>> {
  T? _data;
  Object? _error;
  bool _has = false;
  late final AppState _app;

  @override
  void initState() {
    super.initState();
    _app = context.read<AppState>();
    _app.api.revision.addListener(_quietReload);
    _reload();
  }

  @override
  void didUpdateWidget(LiveData<T> old) {
    super.didUpdateWidget(old);
    if (old.watchKey != widget.watchKey) {
      setState(() {
        _has = false;
        _error = null;
      });
      _reload();
    }
  }

  @override
  void dispose() {
    _app.api.revision.removeListener(_quietReload);
    super.dispose();
  }

  void _quietReload() => _reload();

  Future<void> _reload() async {
    try {
      final data = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = data;
        _has = true;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (!_has) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_has) return widget.builder(context, _data as T, _reload);
    if (_error != null) {
      return ErrorRetry(
        error: _error!,
        onRetry: () {
          setState(() => _error = null);
          _reload();
        },
      );
    }
    return widget.loading ?? const Loading();
  }
}
