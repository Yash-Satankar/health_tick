import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/env.dart';
import '../models/asset_ref.dart';
import '../theme/tokens.dart';

typedef RemoteImageBuilder = Widget Function(BuildContext context, AssetRef asset, BoxFit fit);

/// Network image resolved against API_BASE_URL, cached, with a shimmer placeholder and a
/// broken-image fallback (SPEC §9.6, §10 "Missing image").
class RemoteImage extends StatelessWidget {
  const RemoteImage(this.asset, {super.key, this.fit = BoxFit.contain, this.width, this.height});

  /// Tests replace the network image (plugins are unavailable in widget tests).
  @visibleForTesting
  static RemoteImageBuilder? debugBuilder;

  final AssetRef? asset;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final asset = this.asset;
    Widget child;
    if (asset == null) {
      child = const BrokenImage();
    } else if (debugBuilder != null) {
      child = debugBuilder!(context, asset, fit);
    } else {
      child = CachedNetworkImage(
        imageUrl: Env.resolveAssetUrl(asset.url),
        fit: fit,
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (_, _) => const ShimmerBox(),
        errorWidget: (_, _, _) => const BrokenImage(),
      );
    }
    return Semantics(
      label: asset?.alt,
      image: true,
      child: SizedBox(width: width, height: height, child: child),
    );
  }
}

class BrokenImage extends StatelessWidget {
  const BrokenImage({super.key});

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: AppColors.surface,
    child: Center(child: Icon(Icons.broken_image_outlined, color: AppColors.textSecondary)),
  );
}

/// Simple pulsing placeholder (no extra package).
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({super.key});

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: 0.35, end: 0.8).animate(_controller),
    child: const ColoredBox(color: AppColors.surface, child: SizedBox.expand()),
  );
}
