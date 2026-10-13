import 'package:flutter/foundation.dart';

import '../network/api_client.dart';

/// Asset object from the API: `{ url, width, height, alt, format }` (SPEC §6.1). URL is API-relative.
@immutable
class AssetRef {
  const AssetRef({required this.url, this.width, this.height, this.alt = '', this.format = 'png'});

  final String url;
  final int? width;
  final int? height;
  final String alt;
  final String format;

  double? get aspectRatio => (width != null && height != null && width! > 0 && height! > 0) ? width! / height! : null;

  static AssetRef fromJson(Object? json) {
    final map = asJsonMap(json);
    final url = map['url'];
    if (url is! String || url.isEmpty) throw const FormatException('asset.url missing');
    return AssetRef(
      url: url,
      width: (map['width'] as num?)?.toInt(),
      height: (map['height'] as num?)?.toInt(),
      alt: map['alt'] as String? ?? '',
      format: map['format'] as String? ?? 'png',
    );
  }

  static AssetRef? fromJsonOrNull(Object? json) => json == null ? null : fromJson(json);

  @override
  bool operator ==(Object other) =>
      other is AssetRef && other.url == url && other.width == width && other.height == height && other.alt == alt;
  @override
  int get hashCode => Object.hash(url, width, height, alt);
}
