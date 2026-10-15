import 'package:flutter/material.dart';

class CurioLogoMark extends StatelessWidget {
  const CurioLogoMark({super.key, this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          Align(
            alignment: const Alignment(-0.12, 0.18),
            child: Icon(
              Icons.menu_book_rounded,
              size: size * 0.84,
              color: color,
            ),
          ),
          Align(
            alignment: const Alignment(0.72, -0.7),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: size * 0.39,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
