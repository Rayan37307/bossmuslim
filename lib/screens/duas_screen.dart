import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/duas.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Duas opened as a pushed page (from Home or More).
class DuasPage extends StatelessWidget {
  const DuasPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(toolbarHeight: 48),
        body: const DuasScreen(),
      );
}

class DuasScreen extends StatefulWidget {
  const DuasScreen({super.key});

  @override
  State<DuasScreen> createState() => _DuasScreenState();
}

class _DuasScreenState extends State<DuasScreen> {
  String _category = 'all';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final isList = _category.startsWith('list:');
          final List<Dua> duas;
          if (isList) {
            duas = (state.duaLists[_category.substring(5)] ?? []).map((id) => duaById[id]).whereType<Dua>().toList();
          } else {
            duas = [
              for (final c in duaCategories)
                if (_category == 'all' || c.id == _category) ...c.duas,
            ];
          }
          final filtered = duas
              .where((d) => _query.isEmpty || d.title.toLowerCase().contains(_query) || d.meaning.toLowerCase().contains(_query))
              .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                child: Row(
                  children: [
                    Expanded(child: Text('Duas', style: context.text.headlineMedium?.copyWith(fontSize: 26))),
                    IconButton(
                      tooltip: 'My lists',
                      onPressed: () => showSheet(context, (_) => const _ListsSheet()),
                      icon: const Icon(Icons.playlist_add_check_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                  decoration: const InputDecoration(hintText: 'Search duas', prefixIcon: Icon(Icons.search_rounded)),
                ),
              ),
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  children: [
                    _chip('All', 'all'),
                    for (final l in state.duaLists.keys) _chip(l, 'list:$l', icon: Icons.bookmark_rounded),
                    for (final c in duaCategories) _chip(c.title, c.id),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? ErrorState(
                        icon: isList ? Icons.bookmark_outline_rounded : Icons.search_off_rounded,
                        message: isList ? 'This list is empty.\nTap the bookmark on any dua to add it.' : 'No duas match your search.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => FadeIn(index: i.clamp(0, 6), child: _DuaCard(dua: filtered[i])),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(String label, String id, {IconData? icon}) {
    final selected = _category == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: icon == null ? null : Icon(icon, size: 16, color: selected ? context.colors.primary : context.tokens.muted),
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _category = id),
        labelStyle: TextStyle(color: selected ? context.colors.primary : null, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}

class _DuaCard extends StatelessWidget {
  const _DuaCard({required this.dua});
  final Dua dua;

  @override
  Widget build(BuildContext context) {
    final saved = AppState.instance.isInAnyList(dua.id);
    return Panel(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DuaDetailScreen(dua: dua))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(dua.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
              if (saved) Icon(Icons.bookmark_rounded, size: 18, color: context.colors.primary),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            dua.arabic,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: arabicStyle(size: 22, height: 1.9),
          ),
          const SizedBox(height: 8),
          Text(dua.meaning, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.tokens.muted, height: 1.45, fontSize: 13.5)),
          const SizedBox(height: 10),
          Text(dua.source, style: TextStyle(color: context.colors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class DuaDetailScreen extends StatelessWidget {
  const DuaDetailScreen({super.key, required this.dua});
  final Dua dua;

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              tooltip: 'Copy',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: '${dua.arabic}\n\n${dua.meaning}\n— ${dua.source}'));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dua copied'), duration: Duration(seconds: 1)));
              },
              icon: const Icon(Icons.copy_rounded),
            ),
            IconButton(
              tooltip: 'Save to list',
              onPressed: () => showSheet(context, (_) => _SaveToListSheet(duaId: dua.id)),
              icon: Icon(
                state.isInAnyList(dua.id) ? Icons.bookmark_rounded : Icons.bookmark_add_outlined,
                color: state.isInAnyList(dua.id) ? context.colors.primary : null,
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          children: [
            Text(dua.title, style: context.text.headlineMedium?.copyWith(fontSize: 24)),
            const SizedBox(height: 20),
            Panel(
              padding: const EdgeInsets.all(20),
              child: Text(
                dua.arabic,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: arabicStyle(size: state.arabicSize, height: 2.1),
              ),
            ),
            const SizedBox(height: 20),
            Text('Meaning', style: context.text.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(dua.meaning, style: const TextStyle(fontSize: 16, height: 1.6)),
            if (dua.note != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: context.tokens.accentSoft, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: context.colors.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(dua.note!, style: const TextStyle(height: 1.5, fontSize: 14))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.verified_outlined, size: 16, color: context.tokens.muted),
                const SizedBox(width: 6),
                Text(dua.source, style: TextStyle(color: context.tokens.muted, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveToListSheet extends StatelessWidget {
  const _SaveToListSheet({required this.duaId});
  final String duaId;

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Save to list', style: context.text.titleLarge?.copyWith(fontSize: 18)),
            ),
            for (final e in state.duaLists.entries)
              CheckboxListTile(
                value: e.value.contains(duaId),
                onChanged: (_) => state.toggleDuaInList(e.key, duaId),
                title: Text(e.key),
                subtitle: Text('${e.value.length} duas', style: context.text.bodySmall),
                controlAffinity: ListTileControlAffinity.trailing,
              ),
            ListTile(
              leading: Icon(Icons.add_rounded, color: context.colors.primary),
              title: Text('New list', style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.w600)),
              onTap: () async {
                final name = await _askName(context);
                if (name != null) {
                  await state.createDuaList(name);
                  await state.toggleDuaInList(name, duaId);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ListsSheet extends StatelessWidget {
  const _ListsSheet();

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('My dua lists', style: context.text.titleLarge?.copyWith(fontSize: 18)),
            ),
            for (final e in state.duaLists.entries)
              ListTile(
                leading: const Icon(Icons.bookmark_outline_rounded),
                title: Text(e.key),
                subtitle: Text('${e.value.length} duas', style: context.text.bodySmall),
                trailing: e.key == 'Favorites'
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => state.deleteDuaList(e.key),
                      ),
              ),
            ListTile(
              leading: Icon(Icons.add_rounded, color: context.colors.primary),
              title: Text('Create list', style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.w600)),
              onTap: () async {
                final name = await _askName(context);
                if (name != null) state.createDuaList(name);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

Future<String?> _askName(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('New list'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'e.g. Morning routine'),
        onSubmitted: (v) => Navigator.pop(context, v.trim().isEmpty ? null : v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim().isEmpty ? null : controller.text.trim()),
          child: const Text('Create'),
        ),
      ],
    ),
  );
}
