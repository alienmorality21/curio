import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import '../models/fact.dart';
import '../repositories/fact_republic_repository.dart';
import '../storage/fact_storage.dart';
import '../storage/fact_image_cache.dart';
import '../utils/brave_search.dart';
import '../widgets/fact_image.dart';
import '../widgets/zoomable_fact_image.dart';
import 'settings_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({
    super.key,
    required this.repository,
    this.themePreference = CurioThemePreference.system,
    this.onThemeChanged,
    this.storage,
    this.searchLauncher,
    this.factTextScale = 1,
    this.factLineSpacing = 1.4,
    this.onReadingSettingsChanged,
  });

  final FactRepublicRepository repository;
  final CurioThemePreference themePreference;
  final Future<void> Function(CurioThemePreference)? onThemeChanged;
  final FactStorage? storage;
  final Future<void> Function(String query)? searchLauncher;
  final double factTextScale;
  final double factLineSpacing;
  final Future<void> Function(double textScale, double lineSpacing)?
  onReadingSettingsChanged;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final PageController _pageController = PageController();
  List<Fact> _facts = const [];
  List<Fact> _bookmarks = const [];
  int _currentIndex = 0;
  int _pageGeneration = 0;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  bool _canLoadMore = true;
  bool _isInitializing = true;
  bool _isOffline = false;
  bool _isAdvancingFromImage = false;
  int _requestGeneration = 0;
  String? _errorMessage;
  String? _loadMoreMessage;
  late final FactStorage _storage;
  final FactImageCache _imageCache = FactImageCache();

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? FactStorage();
    _initializeLocalData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    unawaited(_storage.close());
    widget.repository.close();
    super.dispose();
  }

  Future<void> _initializeLocalData() async {
    try {
      final cachedFacts = await _storage.loadCachedFacts();
      if (mounted && cachedFacts.isNotEmpty) {
        setState(() => _facts = _deduplicate(cachedFacts));
      }
    } on Exception catch (error, stackTrace) {
      debugPrint('Could not restore cached facts: $error\n$stackTrace');
    }

    try {
      final bookmarks = await _storage.loadBookmarks();
      if (mounted) setState(() => _bookmarks = bookmarks);
    } on Exception catch (error, stackTrace) {
      debugPrint('Could not restore saved facts: $error\n$stackTrace');
    }

    if (!mounted) return;
    setState(() => _isInitializing = false);
    await _refresh();
  }

  Future<void> _saveCachedFacts(List<Fact> facts) async {
    try {
      await _storage.saveCachedFacts(facts);
    } on Exception catch (error, stackTrace) {
      debugPrint('Could not cache facts for offline use: $error\n$stackTrace');
      if (mounted) {
        setState(
          () => _errorMessage =
              'Facts are available, but could not be saved for offline use.',
        );
      }
    }
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    final generation = ++_requestGeneration;
    setState(() {
      _isRefreshing = true;
      _isLoadingMore = false;
      _canLoadMore = true;
      _loadMoreMessage = null;
      _errorMessage = null;
    });

    try {
      final loaded = await widget.repository.fetchFacts();
      if (!mounted || generation != _requestGeneration) return;
      final oldFact = _facts.isEmpty ? null : _facts[_currentIndex];
      final facts = _deduplicate(loaded);
      if (facts.length > 1 && oldFact != null) {
        final oldIndex = facts.indexWhere((fact) => fact.id == oldFact.id);
        if (oldIndex >= 0) {
          final previouslySeen = facts.take(oldIndex + 1).toList();
          facts.addAll(previouslySeen);
          facts.removeRange(0, oldIndex + 1);
        }
      }
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      setState(() {
        _facts = facts;
        _currentIndex = 0;
        _pageGeneration++;
        _isRefreshing = false;
        _isOffline = false;
      });
      await _saveCachedFacts(facts);
      _prefetchImages(facts.take(3).toList());
      if (facts.length <= 1) {
        _loadMore();
      }
    } on Exception catch (error, stackTrace) {
      debugPrint(
        'Could not refresh Fact Republic generator: $error\n$stackTrace',
      );
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _errorMessage = _facts.isEmpty
            ? 'Could not load facts. Check your connection or try again.'
            : 'You may be offline or the request timed out. Showing saved facts.';
        _isRefreshing = false;
        _isOffline = true;
      });
    }
  }

  List<Fact> _deduplicate(List<Fact> facts) {
    final seen = <String>{};
    return facts.where((fact) => seen.add(fact.id)).toList();
  }

  Future<void> _loadMore() async {
    if (_isRefreshing || _isLoadingMore || !_canLoadMore || _facts.isEmpty) {
      return;
    }
    setState(() {
      _isLoadingMore = true;
      _loadMoreMessage = null;
    });
    final generation = _requestGeneration;
    try {
      final loaded = await widget.repository.fetchFacts();
      if (!mounted || generation != _requestGeneration) return;
      final known = _facts.map((fact) => fact.id).toSet();
      final newFacts = loaded.where((fact) => known.add(fact.id)).toList();
      setState(() {
        _isLoadingMore = false;
        if (newFacts.isEmpty) {
          _canLoadMore = false;
          _loadMoreMessage = 'No new facts right now.';
        } else {
          _facts = [..._facts, ...newFacts];
          _canLoadMore = true;
        }
      });
      if (newFacts.isNotEmpty) {
        await _saveCachedFacts(_facts);
        _prefetchImages(newFacts.take(2).toList());
      }
    } on Exception catch (error, stackTrace) {
      debugPrint('Could not load more generator facts: $error\n$stackTrace');
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _isLoadingMore = false;
        _canLoadMore = false;
        _loadMoreMessage = 'Offline — reconnect to discover more facts.';
        _isOffline = true;
      });
    }
  }

  void _retryLoadMore() {
    setState(() => _canLoadMore = true);
    _loadMore();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _prefetchImages(_facts.skip(index + 1).take(2).toList());
    if (index >= _facts.length - 2) {
      _loadMore();
    }
  }

  Future<void> _navigateFromImage(int index, bool forward) async {
    if (_isAdvancingFromImage) return;
    _isAdvancingFromImage = true;
    try {
      final targetIndex = index + (forward ? 1 : -1);
      if (targetIndex < 0) return;
      if (targetIndex >= _facts.length) await _loadMore();
      if (!mounted || targetIndex >= _facts.length) return;
      await _pageController.animateToPage(
        targetIndex,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } finally {
      _isAdvancingFromImage = false;
    }
  }

  void _prefetchImages(List<Fact> facts) {
    if (facts.isNotEmpty) unawaited(_cacheImages(facts));
  }

  Future<void> _cacheImages(List<Fact> facts) async {
    final updatedFacts = await _imageCache.cacheImages(facts);
    final originalById = {for (final fact in facts) fact.id: fact};
    final changed = updatedFacts
        .where(
          (fact) => originalById[fact.id]?.imageCacheKey != fact.imageCacheKey,
        )
        .toList(growable: false);
    if (changed.isEmpty) return;

    for (final fact in changed) {
      try {
        await _storage.updateCachedFact(fact);
      } on Exception catch (error, stackTrace) {
        debugPrint(
          'Could not persist cached image metadata for ${fact.id}: '
          '$error\n$stackTrace',
        );
      }
    }
    if (!mounted) return;
    final updates = {for (final fact in changed) fact.id: fact};
    final nextFeed = _facts
        .map((fact) => updates[fact.id] ?? fact)
        .toList(growable: false);
    final nextBookmarks = _bookmarks
        .map((fact) => updates[fact.id] ?? fact)
        .toList(growable: false);
    setState(() {
      _facts = nextFeed;
      _bookmarks = nextBookmarks;
    });
    try {
      await _storage.saveBookmarks(nextBookmarks);
    } on Exception catch (error, stackTrace) {
      debugPrint(
        'Could not persist bookmark image metadata: $error\n$stackTrace',
      );
    }
  }

  Future<void> _toggleBookmark(Fact fact) async {
    final wasBookmarked = _bookmarks.any((saved) => saved.id == fact.id);
    final updated = wasBookmarked
        ? _bookmarks.where((saved) => saved.id != fact.id).toList()
        : [..._bookmarks, fact];
    setState(() => _bookmarks = updated);
    try {
      await _storage.saveBookmarks(updated);
      if (mounted) {
        _showMessage(
          wasBookmarked ? 'Removed from saved facts.' : 'Saved offline.',
        );
      }
    } on Exception catch (error, stackTrace) {
      debugPrint('Could not save bookmark: $error\n$stackTrace');
      if (!mounted) return;
      setState(
        () => _bookmarks = wasBookmarked
            ? [...updated, fact]
            : updated.where((saved) => saved.id != fact.id).toList(),
      );
      _showMessage('Could not save this bookmark on the device.');
    }
  }

  Future<void> _removeBookmark(Fact fact) async {
    final updated = _bookmarks
        .where((saved) => saved.id != fact.id)
        .toList(growable: false);
    setState(() => _bookmarks = updated);
    try {
      await _storage.saveBookmarks(updated);
    } on Exception catch (error, stackTrace) {
      debugPrint('Could not remove saved fact: $error\n$stackTrace');
      if (!mounted) return;
      setState(() => _bookmarks = [...updated, fact]);
      _showMessage('Could not update saved facts on the device.');
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SettingsScreen(
          themePreference: widget.themePreference,
          onThemeChanged: (preference) async {
            await widget.onThemeChanged?.call(preference);
          },
          factTextScale: widget.factTextScale,
          factLineSpacing: widget.factLineSpacing,
          onReadingSettingsChanged: widget.onReadingSettingsChanged,
          bookmarks: List.unmodifiable(_bookmarks),
          onRemoveBookmark: (fact) => _removeBookmark(fact),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 14, 8),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: colors.primary),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Curio',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (_isOffline)
                    Tooltip(
                      message: 'Offline · previously downloaded facts remain available',
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.cloud_off_rounded,
                          color: colors.error,
                          size: 20,
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Refresh facts from Fact Republic',
                    onPressed: _isRefreshing ? null : _refresh,
                    icon: _isRefreshing
                        ? const SizedBox.square(
                            dimension: 21,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: _openSettings,
                    icon: const Icon(Icons.settings_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _facts.isEmpty
                  ? _isInitializing || _isRefreshing
                        ? const _LoadingFact()
                        : _emptyState(context)
                  : PageView.builder(
                      key: ValueKey(_pageGeneration),
                      controller: _pageController,
                      itemCount: _facts.length,
                      scrollDirection: Axis.vertical,
                      physics: const BouncingScrollPhysics(),
                      onPageChanged: _onPageChanged,
                      itemBuilder: (context, index) => _FactPage(
                        fact: _facts[index],
                        factTextScale: widget.factTextScale,
                        factLineSpacing: widget.factLineSpacing,
                        isLast: index == _facts.length - 1,
                        isLoadingMore: _isLoadingMore,
                        loadMoreMessage: _loadMoreMessage,
                        onRetryLoadMore: _retryLoadMore,
                        onOpenSource: () => _openSource(_facts[index]),
                        onSearch: (selection) =>
                            _searchFact(_facts[index], selection),
                        isBookmarked: _bookmarks.any(
                          (fact) => fact.id == _facts[index].id,
                        ),
                        onToggleBookmark: () => _toggleBookmark(_facts[index]),
                        onSwipeImage: (forward) =>
                            _navigateFromImage(index, forward),
                      ),
                    ),
            ),
            if (_errorMessage != null && _facts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.error),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (_isRefreshing) {
      return const _LoadingFact();
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: colors.primary),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'No facts were found on the generator page.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSource(Fact fact) async {
    final sourceUrl = fact.sourceUrl;
    if (sourceUrl == null) {
      _showMessage('A cited source was not provided for this fact.');
      return;
    }
    final uri = Uri.tryParse(sourceUrl);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      _showMessage('The cited source link is invalid.');
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) _showMessage('Could not open the cited source.');
    } on Exception catch (error) {
      if (mounted) _showMessage('Could not open the cited source: $error');
    }
  }

  Future<void> _searchFact(Fact fact, String? selection) async {
    final query = selection?.trim().isNotEmpty == true
        ? selection!.trim()
        : '${fact.title}\n${fact.description}';
    try {
      await (widget.searchLauncher ?? openGoogleSearchInBrave)(query);
    } on Exception catch (error) {
      if (mounted) _showMessage('Could not open Google Search: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _FactPage extends StatefulWidget {
  const _FactPage({
    required this.fact,
    required this.factTextScale,
    required this.factLineSpacing,
    required this.isLast,
    required this.isLoadingMore,
    required this.loadMoreMessage,
    required this.onRetryLoadMore,
    required this.onOpenSource,
    required this.onSearch,
    required this.isBookmarked,
    required this.onToggleBookmark,
    required this.onSwipeImage,
  });

  final Fact fact;
  final double factTextScale;
  final double factLineSpacing;
  final bool isLast;
  final bool isLoadingMore;
  final String? loadMoreMessage;
  final VoidCallback onRetryLoadMore;
  final VoidCallback onOpenSource;
  final ValueChanged<String?> onSearch;
  final bool isBookmarked;
  final VoidCallback onToggleBookmark;
  final ValueChanged<bool> onSwipeImage;

  @override
  State<_FactPage> createState() => _FactPageState();
}

class _FactPageState extends State<_FactPage> {
  String? _selectedText;
  bool _showImage = true;
  bool _showFactActions = true;

  void _updateSelection(SelectedContent? content) {
    final selection = content?.plainText.trim();
    if (selection == _selectedText) return;
    setState(() => _selectedText = selection);
  }

  Fact get fact => widget.fact;
  double get factTextScale => widget.factTextScale;
  double get factLineSpacing => widget.factLineSpacing;
  bool get isLast => widget.isLast;
  bool get isLoadingMore => widget.isLoadingMore;
  String? get loadMoreMessage => widget.loadMoreMessage;
  VoidCallback get onRetryLoadMore => widget.onRetryLoadMore;
  VoidCallback get onOpenSource => widget.onOpenSource;
  bool get isBookmarked => widget.isBookmarked;
  VoidCallback get onToggleBookmark => widget.onToggleBookmark;
  ValueChanged<bool> get onSwipeImage => widget.onSwipeImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    var imageDragDistance = 0.0;
    var didNavigateFromImage = false;
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = (math.min(constraints.maxWidth, 680.0) - 40)
            .clamp(1.0, 640.0)
            .toDouble();
        final descriptionStyle =
            (theme.textTheme.bodyLarge ?? const TextStyle()).copyWith(
              fontSize: 18 * factTextScale,
              height: factLineSpacing,
            );
        final descriptionPainter = TextPainter(
          text: TextSpan(text: fact.description, style: descriptionStyle),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: contentWidth);
        final titlePainter = TextPainter(
          text: TextSpan(
            text: fact.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.12,
              fontSize:
                  (theme.textTheme.titleLarge?.fontSize ?? 22) * factTextScale,
            ),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: (contentWidth - 42 - 12 - 48).clamp(1.0, 640.0));
        final useStackedActions =
            contentWidth < 370 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.25;
        final estimatedImageHeight = _showImage
            ? factImageDisplayHeight(
                width: contentWidth,
                aspectRatio: 1,
                maxHeight: constraints.maxHeight * 0.42,
              )
            : 48.0;
        final estimatedContentHeight =
            math.max(42.0, titlePainter.height) +
            14 +
            estimatedImageHeight +
            14 +
            descriptionPainter.height +
            18 +
            (useStackedActions ? 48 * 2 + 10 : 48) +
            18 +
            9 +
            28;
        final needsTextScroll =
            estimatedContentHeight + 16 > constraints.maxHeight;
        final factHeader = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.onSurface,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                fact.number,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.surface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: SelectionArea(
                  onSelectionChanged: _updateSelection,
                  child: Text(
                    fact.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.12,
                      fontSize:
                          (theme.textTheme.titleLarge?.fontSize ?? 22) *
                          factTextScale,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: _showFactActions
                  ? 'Hide source and search actions'
                  : 'Show source and search actions',
              visualDensity: VisualDensity.compact,
              onPressed: () =>
                  setState(() => _showFactActions = !_showFactActions),
              icon: Icon(
                _showFactActions
                    ? Icons.more_horiz_rounded
                    : Icons.more_vert_rounded,
              ),
            ),
            IconButton(
              tooltip: isBookmarked
                  ? 'Remove saved fact'
                  : 'Save fact for offline reading',
              onPressed: onToggleBookmark,
              icon: Icon(
                isBookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: isBookmarked ? colors.primary : null,
              ),
            ),
          ],
        );
        final factImage = _showImage
            ? ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (details) {
                        if (didNavigateFromImage) return;
                        imageDragDistance += details.delta.dy;
                        if (imageDragDistance.abs() >= 36) {
                          didNavigateFromImage = true;
                          onSwipeImage(imageDragDistance < 0);
                        }
                      },
                      onVerticalDragEnd: (details) {
                        final velocity = details.primaryVelocity;
                        if (!didNavigateFromImage &&
                            velocity != null &&
                            velocity.abs() > 250) {
                          onSwipeImage(velocity < 0);
                        }
                      },
                      child: ZoomableFactImage(
                        imageUrl: fact.imageUrl,
                        cacheKey: fact.imageCacheKey,
                        maxHeight: constraints.maxHeight * 0.42,
                      ),
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
            : Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _showImage = true),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Show image'),
                ),
              );
        final factDescription = SelectionArea(
          onSelectionChanged: _updateSelection,
          child: Text(fact.description, style: descriptionStyle),
        );
        final actionContent = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_showFactActions) ...[
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, actionConstraints) {
                  final useStackedActions =
                      actionConstraints.maxWidth < 370 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.25;
                  final sourceButton = OutlinedButton.icon(
                    onPressed: onOpenSource,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Source'),
                  );
                  final searchButton = FilledButton.icon(
                    onPressed: () => widget.onSearch(_selectedText),
                    style: FilledButton.styleFrom(
                      textStyle: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Search with Google'),
                  );
                  if (useStackedActions) {
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
                      const SizedBox(width: 10),
                      Expanded(child: searchButton),
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: 9),
            Center(
              child: isLast && (isLoadingMore || loadMoreMessage != null)
                  ? isLoadingMore
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Finding more facts…'),
                            ],
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  loadMoreMessage!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: onRetryLoadMore,
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 18,
                                ),
                                label: const Text('Retry'),
                              ),
                            ],
                          )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLast
                              ? Icons.refresh_rounded
                              : Icons.keyboard_arrow_up_rounded,
                          size: 19,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            needsTextScroll
                                ? isLast
                                      ? 'Scroll text · swipe image for more'
                                      : 'Scroll text · swipe image to navigate'
                                : isLast
                                ? 'Swipe up for more facts'
                                : 'Swipe up for the next fact',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        );
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: needsTextScroll
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        factHeader,
                        const SizedBox(height: 14),
                        factImage,
                        const SizedBox(height: 14),
                        Expanded(
                          child: SingleChildScrollView(child: factDescription),
                        ),
                        actionContent,
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        factHeader,
                        const SizedBox(height: 14),
                        factImage,
                        const SizedBox(height: 14),
                        factDescription,
                        actionContent,
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _LoadingFact extends StatelessWidget {
  const _LoadingFact();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 18),
          Row(
            children: [
              _SkeletonBox(color: color, width: 42, height: 42),
              const SizedBox(width: 12),
              Expanded(child: _SkeletonBox(color: color, height: 26)),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            flex: 5,
            child: _SkeletonBox(color: color, width: double.infinity),
          ),
          const SizedBox(height: 18),
          _SkeletonBox(color: color, width: double.infinity, height: 18),
          const SizedBox(height: 10),
          _SkeletonBox(color: color, width: double.infinity, height: 18),
          const SizedBox(height: 10),
          _SkeletonBox(color: color, width: 210, height: 18),
          const Spacer(),
          _SkeletonBox(color: color, width: double.infinity, height: 48),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.color, this.width, this.height});

  final Color color;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
