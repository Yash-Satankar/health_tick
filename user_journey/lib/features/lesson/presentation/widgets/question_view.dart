import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/lesson.dart';

/// Option cards with a radio (single) or checkbox (multiple) indicator (SPEC §9.6).
class ChoiceOptions extends StatelessWidget {
  const ChoiceOptions({super.key, required this.question, required this.selected, required this.onToggle});

  final Question question;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final single = question.responseType == ResponseType.singleChoice;
    return Column(
      children: [
        for (final option in question.options)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _OptionCard(
              option: option,
              selected: selected.contains(option.id),
              single: single,
              onTap: () => onToggle(option.id),
            ),
          ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.option, required this.selected, required this.single, required this.onTap});

  final QuestionOption option;
  final bool selected;
  final bool single;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? AppColors.borderSelected : AppColors.border;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        key: ValueKey('option-${option.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radius),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
            color: selected ? AppColors.surface : Colors.transparent,
          ),
          child: Row(
            children: [
              _Indicator(selected: selected, single: single),
              const SizedBox(width: 12),
              Expanded(
                child: Text(option.label, style: const TextStyle(fontSize: AppSizes.bodyFont)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({required this.selected, required this.single});

  final bool selected;
  final bool single;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.borderSelected : AppColors.textSecondary;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: single ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: single ? null : BorderRadius.circular(5),
        border: Border.all(color: color, width: 2),
        color: !single && selected ? AppColors.borderSelected : null,
      ),
      child: selected
          ? single
                ? Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.borderSelected),
                    ),
                  )
                : const Icon(Icons.check_rounded, size: 16, color: AppColors.buttonText)
          : null,
    );
  }
}

/// Multiline box (min 4 lines) with a counter when `maxLength` is set (SPEC §9.6).
class FreeTextInput extends StatefulWidget {
  const FreeTextInput({
    super.key,
    required this.question,
    required this.initialText,
    required this.placeholder,
    required this.onChanged,
  });

  final Question question;
  final String initialText;
  final String placeholder;
  final ValueChanged<String> onChanged;

  @override
  State<FreeTextInput> createState() => _FreeTextInputState();
}

class _FreeTextInputState extends State<FreeTextInput> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('free-text'),
      controller: _controller,
      onChanged: widget.onChanged,
      minLines: 4,
      maxLines: 8,
      maxLength: widget.question.maxLength,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: widget.question.inputPlaceholder ?? widget.placeholder,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.radius)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius),
          borderSide: const BorderSide(color: AppColors.borderSelected),
        ),
      ),
    );
  }
}
