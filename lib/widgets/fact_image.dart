import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../storage/fact_image_cache.dart';

double factImageDisplayHeight({
  required double width,
  required double aspectRatio,
  required double maxHeight,
}) {
  final upperBound = maxHeight.clamp(1.0, double.infinity).toDouble();
  final lowerBound = math.min(110.0, upperBound);
  return (width / aspectRatio).clamp(lowerBound, upperBound).toDouble();
}

class FactImage extends StatefulWidget {
  const FactImage({
    super.key,
    required this.imageUrl,
    this.cacheKey,
    this.maxHeight,
  });

  final String? imageUrl;
  final String? cacheKey;
  final double? maxHeight;

  @override
  State<FactImage> createState() => _FactImageState();
}

class _FactImageState extends State<FactImage> {
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  double? _aspectRatio;
  String? _resolvedUrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImageSize();
  }

  @override
  void didUpdateWidget(covariant FactImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.cacheKey != widget.cacheKey) {
      _removeImageListener();
      _aspectRatio = null;
      _resolvedUrl = null;
      _resolveImageSize();
    }
  }

  void _resolveImageSize() {
    final imageUrl = widget.imageUrl;
    if (imageUrl == null || imageUrl == _resolvedUrl) return;
    _resolvedUrl = imageUrl;
    final pixelWidth =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .ceil()
            .clamp(1, 2048);
    final imageProvider = CachedNetworkImageProvider(
      imageUrl,
      cacheManager: FactImageCache.persistentCacheManager,
      cacheKey: widget.cacheKey ?? imageUrl,
    );
    final stream = ResizeImage.resizeIfNeeded(
      pixelWidth,
      null,
      imageProvider,
    ).resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener(
      (image, synchronousCall) {
        final ratio = image.image.width / image.image.height;
        if (!mounted || ratio == _aspectRatio) return;
        setState(() => _aspectRatio = ratio);
      },
      onError: (error, stackTrace) {
        debugPrint('Could not read fact image dimensions: $error');
      },
    );
    _imageStream = stream;
    _imageListener = listener;
    stream.addListener(listener);
  }

  void _removeImageListener() {
    final stream = _imageStream;
    final listener = _imageListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _imageStream = null;
    _imageListener = null;
  }

  @override
  void dispose() {
    _removeImageListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final pixelWidth = (width * MediaQuery.devicePixelRatioOf(context))
            .ceil()
            .clamp(1, 2048);
        final screenCap = MediaQuery.sizeOf(context).height * 0.9;
        final maxHeight = (widget.maxHeight ?? screenCap)
            .clamp(1.0, screenCap)
            .toDouble();
        final height = factImageDisplayHeight(
          width: width,
          aspectRatio: _aspectRatio ?? 1.8,
          maxHeight: maxHeight,
        );

        return SizedBox(
          width: double.infinity,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(color: colors.surfaceContainerHighest),
            child: widget.imageUrl == null
                ? const _ImagePlaceholder()
                : CachedNetworkImage(
                    imageUrl: widget.imageUrl!,
                    cacheManager: FactImageCache.persistentCacheManager,
                    cacheKey: widget.cacheKey ?? widget.imageUrl,
                    width: double.infinity,
                    height: height,
                    memCacheWidth: pixelWidth,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    fadeInDuration: const Duration(milliseconds: 240),
                    placeholder: (context, url) => const _ImagePlaceholder(),
                    errorWidget: (context, url, error) =>
                        const _ImagePlaceholder(),
                  ),
          ),
        );
      },
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Icon(
        Icons.auto_awesome_rounded,
        color: scheme.primary.withValues(alpha: 0.62),
        size: 38,
      ),
    );
  }
}
