import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:url_launcher/url_launcher.dart';

import '../models/fact.dart';
import '../utils/brave_search.dart';
import '../widgets/zoomable_fact_image.dart';

class FactDetailScreen extends StatefulWidget {
  const FactDetailScreen({
    super.key,
    required this.fact,
    required this.isSaved,
    required this.onToggleSaved,
    this.factTextScale = 1,
    this.factLineSpacing = 1.4,
  });

  final Fact fact;
  final bool isSaved;
  final VoidCallback onToggleSaved;
  final double factTextScale;
  final double factLineSpacing;

  @override
  State<FactDetailScreen> createState() => _FactDetailScreenState();
}

class _FactDetailScreenState extends State<FactDetailScreen> {
  String? _selectedText;
  bool _showImage = true;
  bool _showFactActions = true;

  Fact get fact => widget.fact;
  bool get isSaved => widget.isSaved;
  VoidCallback get onToggleSaved => widget.onToggleSaved;
  double get factTextScale => widget.factTextScale;
  double get factLineSpacing => widget.factLineSpacing;

  void _updateSelection(SelectedContent? content) {
    final selection = content?.plainText.trim();
    if (selection == _selectedText) return;
    setState(() => _selectedText = selection);
  }

  Future<void> _openSource(BuildContext context) async {
    final sourceUrl = fact.sourceUrl;
    if (sourceUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cited source was provided.')),
      );
      return;
    }
    final uri = Uri.tryParse(sourceUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The cited source link is invalid.')),
      );
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the cited source.')),
        );
      }
    } on Exception catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open the cited source: $error')),
        );
      }
    }
  }

  Future<void> _search(BuildContext context) async {
    final query = _selectedText?.isNotEmpty == true
        ? _selectedText!
        : '${fact.title}\n${fact.description}';
    try {
      await openGoogleSearchInBrave(query);
    } on Exception catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open Google Search: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved fact'),
        actions: [
          IconButton(
            tooltip: _showFactActions
                ? 'Hide source and search actions'
                : 'Show source and search actions',
            onPressed: () =>
                setState(() => _showFactActions = !_showFactActions),
            icon: Icon(
              _showFactActions
                  ? Icons.more_horiz_rounded
                  : Icons.more_vert_rounded,
            ),
          ),
          IconButton(
            tooltip: isSaved ? 'Remove saved fact' : 'Save fact',
            onPressed: onToggleSaved,
            icon: Icon(
              isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: isSaved ? colors.primary : null,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (fact.category != null) ...[
                Text(
                  fact.category!,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SelectionArea(
                onSelectionChanged: _updateSelection,
                child: Text(
                  fact.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize:
                        (theme.textTheme.headlineSmall?.fontSize ?? 24) *
                        factTextScale,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_showImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      ZoomableFactImage(
                        imageUrl: fact.imageUrl,
                        cacheKey: fact.imageCacheKey,
                        maxHeight: MediaQuery.sizeOf(context).height * 0.42,
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: IconButton(
                            tooltip: 'Hide image',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setState(() => _showImage = false),
                            color: Colors.white,
                            icon: const Icon(Icons.visibility_off_rounded),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showImage = true),
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Show image'),
                  ),
                ),
              const SizedBox(height: 18),
              SelectionArea(
                onSelectionChanged: _updateSelection,
                child: Text(
                  fact.description,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 18 * factTextScale,
                    height: factLineSpacing,
                  ),
                ),
              ),
              if (fact.sourceName != null || fact.sourceUrl != null) ...[
                const SizedBox(height: 18),
                Text(
                  fact.sourceName == null
                      ? 'Source'
                      : 'Source: ${fact.sourceName}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
              if (_showFactActions) ...[
                const SizedBox(height: 24),
                LayoutBuilder(
                builder: (context, constraints) {
                  final sourceButton = OutlinedButton.icon(
                    onPressed: () => _openSource(context),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Source'),
                  );
                  final searchButton = FilledButton.icon(
                    onPressed: () => _search(context),
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Search with Google'),
                  );
                  if (constraints.maxWidth < 370 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.25) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        sourceButton,
                        const SizedBox(height: 10),
                        searchButton,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: sourceButton),
                      const SizedBox(width: 12),
                      Expanded(child: searchButton),
                    ],
                  );
                },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
