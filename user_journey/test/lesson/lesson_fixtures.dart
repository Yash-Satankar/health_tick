import 'package:user_journey/core/models/asset_ref.dart';
import 'package:user_journey/features/lesson/domain/lesson.dart';

const img = AssetRef(url: '/static/assets/lesson_dominoes.png', width: 556, height: 319);

/// A lesson covering every page kind:
/// 0 content (all block types) · 1 graded single choice · 2 ungraded multiple choice (max 2) ·
/// 3 free text (answer_key big_goal) · 4 content using {{answer.big_goal}} (last page).
Lesson sampleLesson({bool isSaved = false}) => Lesson(
  id: 'lesson-1',
  title: 'Sample lesson',
  nodeId: 'node-1',
  nodeType: 'lesson',
  isSaved: isSaved,
  pages: [
    const LessonPage(
      id: 'p0',
      position: 0,
      type: PageType.content,
      ctaLabel: "THAT'S IMPRACTICAL!",
      blocks: [
        HeadingBlock('b-heading', "It's going to be different this time!"),
        ParagraphBlock('b-para', 'Hello {{user.name}}! ==Only to give up after 2 to 3 weeks!=='),
        ListBlock('b-ol', ['Number one, **no junk Food!**', 'Number two'], ordered: true),
        ListBlock('b-ul', ['They will start exercising daily.'], ordered: false),
        ImageBlock('b-img', img),
        CalloutBlock('b-callout', "**We're a team of psychologists**", img),
        IconHeadingBlock('b-icon', 'ZONE-1', '#F5A04A', img),
        AccordionBlock('b-acc', 'A few examples of Zone 1 foods', [
          ListBlock('b-acc-1', ['Cucumber', 'Skim milk'], ordered: false),
        ]),
        SpacerBlock('b-spacer', 12),
      ],
    ),
    const LessonPage(
      id: 'p1',
      position: 1,
      type: PageType.question,
      ctaLabel: 'NEXT',
      blocks: [ParagraphBlock('q1', 'First question is - *What is Calorie Density?*')],
      question: Question(
        responseType: ResponseType.singleChoice,
        isGraded: true,
        maxSelections: 1,
        options: [
          QuestionOption(id: 'o-a', label: 'The total calories I eat in one day'),
          QuestionOption(id: 'o-b', label: 'The number of calories in a food per gram of its weight'),
        ],
      ),
    ),
    const LessonPage(
      id: 'p2',
      position: 2,
      type: PageType.question,
      ctaLabel: 'NEXT',
      blocks: [ParagraphBlock('q2', 'Why do you think we humans eat?')],
      question: Question(
        responseType: ResponseType.multipleChoice,
        isGraded: false,
        minSelections: 1,
        maxSelections: 2,
        options: [
          QuestionOption(id: 'm-1', label: 'Hunger'),
          QuestionOption(id: 'm-2', label: 'Thirst'),
          QuestionOption(id: 'm-3', label: 'Stress'),
        ],
      ),
    ),
    const LessonPage(
      id: 'p3',
      position: 3,
      type: PageType.question,
      ctaLabel: 'DONE',
      blocks: [ParagraphBlock('q3', '*(Write it below)*')],
      question: Question(
        responseType: ResponseType.freeText,
        isGraded: false,
        options: [],
        answerKey: 'big_goal',
        minLength: 1,
        maxLength: 300,
        validationMessage: 'Writing your thoughts will help you remember and build habits.',
      ),
    ),
    const LessonPage(
      id: 'p4',
      position: 4,
      type: PageType.content,
      ctaLabel: 'SOUNDS GOOD',
      blocks: [ParagraphBlock('b-goal', '==**Your big goal**== : {{answer.big_goal}}')],
    ),
  ],
);

const wrongFeedback = AnswerFeedback(
  headline: 'Not quite, but I appreciate your effort.',
  illustration: AssetRef(url: '/static/assets/feedback_oops_sign.png', width: 142, height: 250),
  correctAnswers: ['The number of calories in a food per gram of its weight'],
  explanation: 'Raisins are simply dehydrated grapes.\n\n(Remember, water has 0 calories)',
);

const sampleCompletion = LessonCompletion(
  attemptId: 'attempt-1',
  firstCompletion: true,
  healthPointsEarned: 5,
  healthPointsTotal: 42,
  nodeCompleted: true,
  unlockedNodeId: 'node-2',
  headline: 'You have won the day 😎',
  message: 'You just understood all the important points.',
);
