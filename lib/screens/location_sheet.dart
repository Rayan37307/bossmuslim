import 'dart:async';

import 'package:flutter/material.dart';

import '../services/location_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Bottom sheet to pick a location via GPS or city search. Returns true if changed.
Future<bool> pickLocation(BuildContext context) async =>
    await showSheet<bool>(context, (_) => const _LocationSheet()) ?? false;

class _LocationSheet extends StatefulWidget {
  const _LocationSheet();

  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<SavedLocation> _results = [];
  bool _searching = false;
  bool _locating = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      setState(() {
        _searching = true;
        _error = null;
      });
      try {
        final r = await LocationService.search(q.trim());
        if (mounted) setState(() => _results = r);
      } catch (_) {
        if (mounted) setState(() => _error = 'Search failed. Check your connection.');
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  Future<void> _useGps() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      final loc = await LocationService.current();
      await AppState.instance.setLocation(loc);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e is LocationException ? e.message : 'Could not get your location.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _choose(SavedLocation l) async {
    await AppState.instance.setLocation(l);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Location', style: context.text.titleLarge?.copyWith(fontSize: 18)),
              const SizedBox(height: 4),
              Text('Currently: ${AppState.instance.location.name}', style: context.text.bodySmall),
              const SizedBox(height: 16),
              Panel(
                onTap: _locating ? null : _useGps,
                child: Row(
                  children: [
                    const IconTile(Icons.my_location_rounded),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Use current location', style: TextStyle(fontWeight: FontWeight.w600)),
                          SizedBox(height: 2),
                          Text('Most accurate prayer times', style: TextStyle(fontSize: 12.5)),
                        ],
                      ),
                    ),
                    if (_locating)
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      Icon(Icons.chevron_right_rounded, color: context.tokens.muted),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search city',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : null,
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (_, i) {
                    final r = _results[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: const Icon(Icons.place_outlined),
                      title: Text(r.name),
                      subtitle: Text('${r.lat.toStringAsFixed(3)}, ${r.lng.toStringAsFixed(3)}', style: context.text.bodySmall),
                      onTap: () => _choose(r),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
