import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/fact.dart';
import '../widgets/fact_image.dart';
import 'fact_detail_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.themePreference,
    required this.onThemeChanged,
    required this.bookmarks,
    required this.onRemoveBookmark,
    this.factTextScale = 1,
    this.factLineSpacing = 1.4,
    this.onReadingSettingsChanged,
  });

  final CurioThemePreference themePreference;
  final Future<void> Function(CurioThemePreference) onThemeChanged;
  final List<Fact> bookmarks;
  final ValueChanged<Fact> onRemoveBookmark;
  final double factTextScale;
  final double factLineSpacing;
  final Future<void> Function(double textScale, double lineSpacing)?
  onReadingSettingsChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late CurioThemePreference _selectedTheme;
  late List<Fact> _bookmarks;
  late double _factTextScale;
  late double _factLineSpacing;
  late double _savedFactTextScale;
  late double _savedFactLineSpacing;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedTheme = widget.themePreference;
    _bookmarks = List.of(widget.bookmarks);
    _factTextScale = widget.factTextScale;
    _factLineSpacing = widget.factLineSpacing;
    _savedFactTextScale = widget.factTextScale;
    _savedFactLineSpacing = widget.factLineSpacing;
  }

  Future<void> _selectTheme(CurioThemePreference preference) async {
    final previous = _selectedTheme;
    setState(() => _selectedTheme = preference);
    try {
      await widget.onThemeChanged(preference);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _selectedTheme = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save theme preference: $error')),
      );
    }
  }

  Future<void> _updateReadingSettings({
    double? textScale,
    double? lineSpacing,
  }) async {
    final nextScale = textScale ?? _factTextScale;
    final nextSpacing = lineSpacing ?? _factLineSpacing;
    setState(() {
      _factTextScale = nextScale;
      _factLineSpacing = nextSpacing;
    });
    try {
      await widget.onReadingSettingsChanged?.call(nextScale, nextSpacing);
      _savedFactTextScale = nextScale;
      _savedFactLineSpacing = nextSpacing;
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _factTextScale = _savedFactTextScale;
        _factLineSpacing = _savedFactLineSpacing;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save reading settings: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final visibleBookmarks = _bookmarks
        .where((fact) {
          final query = _searchQuery.trim().toLowerCase();
          return query.isEmpty ||
              fact.title.toLowerCase().contains(query) ||
              fact.description.toLowerCase().contains(query) ||
              (fact.category?.toLowerCase().contains(query) ?? false);
        })
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text('Appearance', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Themes',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            RadioGroup<CurioThemePreference>(
              groupValue: _selectedTheme,
              onChanged: (value) {
                if (value != null) _selectTheme(value);
              },
              child: Column(
                children: [
                  for (final preference in CurioThemePreference.values)
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: RadioListTile<CurioThemePreference>(
                        value: preference,
                        title: Text(preference.label),
                        subtitle: Text(preference.description),
                        secondary: _ThemePreview(preference: preference),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Reading', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.text_fields_rounded),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Text size',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        Text('${(_factTextScale * 100).round()}%'),
                      ],
                    ),
                    Slider(
                      value: _factTextScale,
                      min: 0.8,
                      max: 1.4,
                      divisions: 6,
                      label: '${(_factTextScale * 100).round()}%',
                      onChanged: (value) =>
                          setState(() => _factTextScale = value),
                      onChangeEnd: (value) =>
                          _updateReadingSettings(textScale: value),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.format_line_spacing_rounded),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Line spacing',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        Text('${_factLineSpacing.toStringAsFixed(1)}×'),
                      ],
                    ),
                    Slider(
                      value: _factLineSpacing,
                      min: 1.1,
                      max: 1.8,
                      divisions: 7,
                      label: '${_factLineSpacing.toStringAsFixed(1)}×',
                      onChanged: (value) =>
                          setState(() => _factLineSpacing = value),
                      onChangeEnd: (value) =>
                          _updateReadingSettings(lineSpacing: value),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Preview: Curio facts are easier to read.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 18 * _factTextScale,
                        height: _factLineSpacing,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: Text('Saved facts', style: theme.textTheme.titleLarge),
                ),
                Text(
                  '${_bookmarks.length}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_bookmarks.length > 4)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: 'Search saved facts',
                    filled: true,
                    fillColor: colors.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            if (_bookmarks.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Facts you bookmark will be kept on this device and available offline.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              )
            else if (visibleBookmarks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No saved facts match that search.'),
              )
            else
              for (final fact in visibleBookmarks)
                _SavedFactCard(
                  fact: fact,
                  onOpen: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => FactDetailScreen(
                        fact: fact,
                        isSaved: true,
                                factTextScale: _factTextScale,
                                factLineSpacing: _factLineSpacing,
                        onToggleSaved: () {
                          setState(
                            () => _bookmarks.removeWhere(
                              (saved) => saved.id == fact.id,
                            ),
                          );
                          widget.onRemoveBookmark(fact);
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ),
                  onRemove: () {
                    setState(
                      () => _bookmarks.removeWhere(
                        (saved) => saved.id == fact.id,
                      ),
                    );
                    widget.onRemoveBookmark(fact);
                  },
                ),
          ],
        ),
      ),
    );
  }
}

class _SavedFactCard extends StatelessWidget {
  const _SavedFactCard({
    required this.fact,
    required this.onOpen,
    required this.onRemove,
  });

  final Fact fact;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 76,
                  child: FactImage(
                    imageUrl: fact.imageUrl,
                    cacheKey: fact.imageCacheKey,
                    maxHeight: 88,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fact.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fact.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bookmark_rounded,
                          color: colors.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          fact.category ?? 'Saved offline',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove ${fact.title} from saved facts',
                onPressed: onRemove,
                icon: const Icon(Icons.bookmark_remove_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.preference});

  final CurioThemePreference preference;

  @override
  Widget build(BuildContext context) {
    final colors = switch (preference) {
      CurioThemePreference.system => Theme.of(context).colorScheme,
      CurioThemePreference.dark => curioTheme(Brightness.dark).colorScheme,
      CurioThemePreference.light => curioTheme(Brightness.light).colorScheme,
      CurioThemePreference.oled => curioTheme(
        Brightness.dark,
        oled: true,
      ).colorScheme,
    };
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.circle, size: 14, color: colors.primary),
    );
  }
}
