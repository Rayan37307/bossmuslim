import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/location_service.dart';
import '../services/mosque_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class MosquesScreen extends StatefulWidget {
  const MosquesScreen({super.key});

  @override
  State<MosquesScreen> createState() => _MosquesScreenState();
}

class _MosquesScreenState extends State<MosquesScreen> {
  int _radius = 3000;
  late Future<List<Mosque>> _future;
  double _lat = AppState.instance.location.lat;
  double _lng = AppState.instance.location.lng;
  bool _usingGps = false;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
    _refineWithGps();
  }

  Future<List<Mosque>> _fetch() => MosqueService.nearby(_lat, _lng, radius: _radius);

  /// Saved location may be a city centre; try the precise position quietly.
  Future<void> _refineWithGps() async {
    try {
      final loc = await LocationService.current();
      if (!mounted) return;
      setState(() {
        _lat = loc.lat;
        _lng = loc.lng;
        _usingGps = true;
        _future = _fetch();
      });
    } catch (_) {}
  }

  void _setRadius(int r) => setState(() {
        _radius = r;
        _future = _fetch();
      });

  Future<void> _directions(Mosque m) async {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${m.lat},${m.lng}&travelmode=walking');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open maps')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Mosques')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Row(
              children: [
                Icon(_usingGps ? Icons.my_location_rounded : Icons.place_outlined, size: 14, color: context.tokens.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _usingGps ? 'Using your current position' : 'Around ${AppState.instance.location.name}',
                    style: context.text.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              children: [
                for (final r in [1000, 3000, 5000, 10000])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('${r ~/ 1000} km'),
                      selected: _radius == r,
                      onSelected: (_) => _setRadius(r),
                      labelStyle: TextStyle(
                        color: _radius == r ? context.colors.primary : null,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Mosque>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const Loading();
                if (snap.hasError) {
                  return ErrorState(message: 'Couldn\'t load mosques.\nCheck your connection and try again.', onRetry: () => setState(() => _future = _fetch()));
                }
                final list = snap.data!;
                if (list.isEmpty) {
                  return ErrorState(
                    icon: Icons.mosque_outlined,
                    message: 'No mosques found within ${_radius ~/ 1000} km.',
                    onRetry: _radius < 10000 ? () => _setRadius(10000) : null,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() => _future = _fetch());
                    await _future;
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    itemCount: list.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      if (i == list.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('Data © OpenStreetMap contributors', textAlign: TextAlign.center, style: context.text.bodySmall?.copyWith(fontSize: 11)),
                        );
                      }
                      final m = list[i];
                      return FadeIn(
                        index: i.clamp(0, 6),
                        child: Panel(
                          onTap: () => _directions(m),
                          child: Row(
                            children: [
                              const IconTile(Icons.mosque_rounded),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Text(
                                      [fmtDistance(m.distance), if (m.address != null) m.address!].join(' · '),
                                      style: context.text.bodySmall,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.directions_rounded, color: context.colors.primary),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
