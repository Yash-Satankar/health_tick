import 'package:flutter/material.dart';

import '../../../../core/widgets/remote_image.dart';
import '../../domain/journey.dart';

/// Level card (SPEC §9.4): radius 16, solid 8 dp offset shadow, illustration on the left 40%,
/// "Status" label / status title / level label / level title on the right. Colours from the API.
class StatusCard extends StatelessWidget {
  const StatusCard({super.key, required this.status, required this.level, required this.statusLabel});

  final JourneyStatus status;
  final JourneyLevel level;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    final theme = status.cardTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / 400;
        TextStyle style(double size, FontWeight weight) =>
            TextStyle(color: theme.text, fontSize: size * scale.clamp(0.8, 1.2), fontWeight: weight, height: 1.2);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: theme.background,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: theme.shadow, offset: const Offset(0, 8))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 40, child: RemoteImage(level.illustration, fit: BoxFit.cover)),
                Expanded(
                  flex: 60,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 12 * scale),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(statusLabel, style: style(14, FontWeight.w500)),
                        Text(
                          status.title,
                          style: style(26, FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 10 * scale),
                        Text(level.label, style: style(13, FontWeight.w700)),
                        Text(
                          level.title,
                          style: style(16, FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
