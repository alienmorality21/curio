import 'package:flutter/material.dart';

import 'fact_image.dart';

class ZoomableFactImage extends StatelessWidget {
  const ZoomableFactImage({
    super.key,
    required this.imageUrl,
    this.cacheKey,
    this.maxHeight,
  });

  final String? imageUrl;
  final String? cacheKey;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: imageUrl == null
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                fullscreenDialog: true,
                builder: (context) => _FullScreenFactImage(
                  imageUrl: imageUrl!,
                  cacheKey: cacheKey,
                ),
              ),
            ),
      child: FactImage(
        imageUrl: imageUrl,
        cacheKey: cacheKey,
        maxHeight: maxHeight,
      ),
    );
  }
}

class _FullScreenFactImage extends StatelessWidget {
  const _FullScreenFactImage({required this.imageUrl, this.cacheKey});

  final String imageUrl;
  final String? cacheKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Image'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => Center(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: FactImage(
                imageUrl: imageUrl,
                cacheKey: cacheKey,
                maxHeight: constraints.maxHeight,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
