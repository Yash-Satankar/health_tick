import 'package:flutter/material.dart';

import '../../../../core/markup/markup_parser.dart';
import '../../../../core/markup/markup_text.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/remote_image.dart';
import '../../domain/lesson.dart';

/// Renders one content block (SPEC §9.6). Tokens are interpolated with [resolver].
class BlockView extends StatelessWidget {
  const BlockView({super.key, required this.block, required this.resolver});

  final LessonBlock block;
  final TokenResolver resolver;

  @override
  Widget build(BuildContext context) {
    final block = this.block;
    return switch (block) {
      HeadingBlock(:final text) => MarkupText(
        text,
        resolver: resolver,
        style: const TextStyle(fontSize: AppSizes.headingFont, fontWeight: FontWeight.w700, height: 1.3),
      ),
      ParagraphBlock(:final text) => MarkupText(text, resolver: resolver),
      ListBlock(:final items, :final ordered) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      ordered ? '${i + 1}.' : '•',
                      style: const TextStyle(fontSize: AppSizes.bodyFont, height: 1.45, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(child: MarkupText(items[i], resolver: resolver)),
                ],
              ),
            ),
        ],
      ),
      ImageBlock(:final asset) => ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radius),
        child: AspectRatio(
          aspectRatio: asset?.aspectRatio ?? 16 / 9,
          child: RemoteImage(asset, fit: BoxFit.cover),
        ),
      ),
      CalloutBlock(:final text, :final asset) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          RemoteImage(asset, width: 56, height: 56),
          const SizedBox(width: 12),
          Expanded(child: MarkupText(text, resolver: resolver)),
        ],
      ),
      IconHeadingBlock(:final text, :final color, :final asset) => Row(
        children: [
          if (asset != null) ...[RemoteImage(asset, width: 24, height: 24), const SizedBox(width: 8)],
          Expanded(
            child: Text(
              resolver.interpolate(text),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: parseHexColor(color)),
            ),
          ),
        ],
      ),
      AccordionBlock() => _Accordion(block: block, resolver: resolver),
      SpacerBlock(:final size) => SizedBox(height: size),
    };
  }
}

/// Tappable title with a chevron; children expand over 200 ms.
class _Accordion extends StatefulWidget {
  const _Accordion({required this.block, required this.resolver});

  final AccordionBlock block;
  final TokenResolver resolver;

  @override
  State<_Accordion> createState() => _AccordionState();
}

class _AccordionState extends State<_Accordion> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSizes.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: ValueKey('accordion-${widget.block.id}'),
            borderRadius: BorderRadius.circular(AppSizes.radius),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: MarkupText(
                      widget.block.title,
                      resolver: widget.resolver,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: AppDurations.accordion,
                    child: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: AppDurations.accordion,
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(
                    key: ValueKey('accordion-body-${widget.block.id}'),
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final child in widget.block.children)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: BlockView(block: child, resolver: widget.resolver),
                          ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
