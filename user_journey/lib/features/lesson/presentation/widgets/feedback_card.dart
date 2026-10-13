import 'package:flutter/material.dart';

import '../../../../core/markup/markup_parser.dart';
import '../../../../core/markup/markup_text.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/remote_image.dart';
import '../../domain/lesson.dart';

/// Answer feedback (SPEC §9.6): illustration (~0.3W), bold centred headline, the answer prefix followed by
/// the highlighted correct answer(s), then the explanation paragraphs.
class FeedbackCard extends StatelessWidget {
  const FeedbackCard({super.key, required this.feedback, required this.answerPrefix, required this.resolver});

  final AnswerFeedback feedback;
  final String answerPrefix;
  final TokenResolver resolver;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Container(
      key: const ValueKey('feedback-card'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: RemoteImage(feedback.illustration, width: width * 0.3, height: width * 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            feedback.headline,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          if (feedback.correctAnswers.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: answerPrefix),
                  TextSpan(
                    text: feedback.correctAnswers.join(', '),
                    style: const TextStyle(
                      backgroundColor: AppColors.highlight,
                      color: AppColors.highlightText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              key: const ValueKey('feedback-correct-answer'),
              style: const TextStyle(fontSize: AppSizes.bodyFont, height: 1.5),
            ),
          ],
          if (feedback.explanation != null)
            for (final paragraph in MarkupParser.paragraphs(feedback.explanation!))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: MarkupText(paragraph, resolver: resolver),
              ),
        ],
      ),
    );
  }
}
