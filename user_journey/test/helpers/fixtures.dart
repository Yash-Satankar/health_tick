import 'package:user_journey/core/copy/app_copy.dart';
import 'package:user_journey/features/app_config/data/bootstrap_dto.dart';
import 'package:user_journey/features/app_config/domain/bootstrap.dart';
import 'package:user_journey/features/journey/data/journey_dto.dart';
import 'package:user_journey/features/journey/domain/journey.dart';

/// Test copy (mirrors keys of the seed `app_copy`; values only need to be recognisable).
const testCopy = <String, String>{
  'home.header.profile': 'profile',
  'home.header.streak': 'streak',
  'home.header.health_points': 'health points',
  'home.today_task.title': "today's task",
  'home.today_task.journey_link': 'JOURNEY',
  'home.today_task.all_done': 'You have completed your journey!',
  'journey.title': 'Your Journey',
  'journey.reload': 'Reload',
  'journey.search': 'Search',
  'journey.reloading.title': 'Reloading Your Journey',
  'journey.reloading.subtitle': 'Please wait while we reload your journey',
  'journey.card.status_label': 'Status',
  'journey.popover.do_it_again': 'DO IT AGAIN',
  'journey.popover.start': 'START',
  'journey.popover.continue': 'CONTINUE',
  'journey.popover.completed_on': 'Completed On',
  'journey.locked.message': 'Complete the previous step to unlock this one.',
  'journey.updated.toast': 'Your journey was updated',
  'search.placeholder': 'Search Lesson...',
  'search.empty.title': 'Start typing to search lessons',
  'search.no_results.title': 'No lessons found',
  'search.sort.relevance': 'Most relevant',
  'search.sort.journey': 'Journey order',
  'search.result.locked': 'Locked',
  'lesson.exit.title': 'You have not completed this section yet',
  'lesson.exit.message': 'Your progress will be lost.',
  'lesson.exit.confirm': 'Exit Anyway',
  'lesson.exit.cancel': "Let's Complete",
  'lesson.menu.save': 'Save Lesson',
  'lesson.menu.saved': 'Lesson saved',
  'lesson.menu.unsave': 'Remove from saved',
  'lesson.menu.feedback': 'Send feedback',
  'lesson.saved.toast.title': 'DONE!',
  'lesson.saved.toast.message': 'Bookmark Added 😁',
  'lesson.feedback.title': 'Faced some issue ?',
  'lesson.feedback.subtitle': 'Please tell us what happened',
  'lesson.feedback.other_placeholder': 'Other (please specify)',
  'lesson.feedback.footer': 'This will help improve the content of our course.',
  'lesson.feedback.submit': 'SUBMIT',
  'lesson.feedback.sent.toast': 'Thanks! Your feedback has been sent.',
  'lesson.feedback.other_required': 'Please tell us a little more in the text box.',
  'lesson.free_text.placeholder': 'Type your response here.',
  'lesson.free_text.validation_title': 'Hello!',
  'lesson.choice.validation_message': 'Please choose an answer to continue.',
  'lesson.feedback_card.answer_prefix': "It's - ",
  'lesson.completion.continue': 'Continue',
  'error.network.title': "You're offline (api)",
  'error.network.message': 'Check your internet connection and try again. (api)',
  'error.timeout.message': 'This is taking longer than usual. (api)',
  'error.server.message': 'Something went wrong on our side. (api)',
  'error.not_found.message': "We couldn't find that. (api)",
  'error.locked.message': 'This lesson is still locked. (api)',
  'error.unexpected.message': 'Something unexpected happened. (api)',
  'error.retry': 'Retry',
};

Bootstrap testBootstrap({int contentVersion = 1, int healthPointsTotal = 0}) => BootstrapDto.fromJson({
  'contentVersion': contentVersion,
  'user': {'id': 'user-1', 'displayName': 'Yash', 'healthPointsTotal': healthPointsTotal},
  'copy': testCopy,
  'assets': {
    'lockedNode': {'url': '/static/assets/node_locked.png', 'width': 114, 'height': 114},
    'completionMedal': {'url': '/static/assets/ui_completion_medal.png', 'width': 229, 'height': 287},
  },
  'feedbackReasons': [
    {'id': 'r-heavy', 'key': 'too_text_heavy', 'label': 'Too text heavy', 'requiresText': false},
    {'id': 'r-read', 'key': 'hard_to_read', 'label': 'Hard to read', 'requiresText': false},
    {'id': 'r-others', 'key': 'others', 'label': 'Others', 'requiresText': true},
  ],
}).toDomain();

const AppCopy appCopy = AppCopy(testCopy);

Map<String, Object?> _asset(String name) => {
  'url': '/static/assets/$name.png',
  'width': 114,
  'height': 114,
  'alt': name,
};

/// Node JSON. [completedLessons] lessons are completed; the node state is given explicitly.
Map<String, Object?> nodeJson(
  String id, {
  String type = 'lesson',
  String state = 'locked',
  int lessons = 2,
  int completedLessons = 0,
  String? completedAt,
}) => {
  'id': id,
  'key': id,
  'type': type,
  'title': type == 'checkpoint' ? 'Checkpoint' : 'Day $id',
  'icon': _asset(type == 'checkpoint' ? 'node_checkpoint_arch' : 'node_psychology'),
  'state': state,
  'completedAt': completedAt,
  'lessons': [
    for (var i = 0; i < lessons; i++)
      {
        'id': '$id-l$i',
        'title': 'Lesson $i of $id',
        'state': i < completedLessons
            ? 'completed'
            : state == 'locked'
            ? 'locked'
            : (i == completedLessons ? 'available' : 'locked'),
        'completedAt': i < completedLessons ? '2026-10-12T10:00:00Z' : null,
      },
  ],
};

/// A journey with Beginner ([beginner] lesson nodes + checkpoint) and Insider ([insider] nodes).
/// The first [completed] nodes are completed, the next one is available.
Map<String, Object?> journeyJson({
  int beginner = 6,
  int insider = 3,
  int completed = 0,
  bool checkpoint = true,
  int contentVersion = 1,
}) {
  var index = 0;
  Map<String, Object?> next(String id, {String type = 'lesson'}) {
    final i = index++;
    final state = i < completed ? 'completed' : (i == completed ? 'available' : 'locked');
    return nodeJson(
      id,
      type: type,
      state: state,
      lessons: type == 'checkpoint' ? 1 : 2,
      completedLessons: state == 'completed' ? (type == 'checkpoint' ? 1 : 2) : 0,
      completedAt: state == 'completed' ? '2026-10-12T10:00:00Z' : null,
    );
  }

  return {
    'contentVersion': contentVersion,
    'statuses': [
      {
        'id': 's-beginner',
        'key': 'beginner',
        'title': 'Beginner',
        'cardTheme': {'backgroundColor': '#F9E4C9', 'shadowColor': '#DBC4A5', 'textColor': '#1C1C1C'},
        'levels': [
          {
            'id': 'lv-1',
            'key': 'beginner_l1',
            'label': 'LEVEL-1',
            'title': 'Psychology of weight',
            'illustration': _asset('card_beginner_illustration'),
            'nodes': [for (var i = 1; i <= beginner; i++) next('b$i'), if (checkpoint) next('cp', type: 'checkpoint')],
          },
        ],
      },
      {
        'id': 's-insider',
        'key': 'insider',
        'title': 'Insider',
        'cardTheme': {'backgroundColor': '#DFECFF', 'shadowColor': '#8CB3D8', 'textColor': '#1C1C1C'},
        'levels': [
          {
            'id': 'lv-2',
            'key': 'insider_l2',
            'label': 'LEVEL-2',
            'title': 'Handle your food triggers',
            'illustration': _asset('card_insider_illustration'),
            'nodes': [for (var i = 1; i <= insider; i++) next('i$i')],
          },
        ],
      },
    ],
  };
}

Journey testJourney({int beginner = 6, int insider = 3, int completed = 0, bool checkpoint = true, int version = 1}) =>
    parseJourney(
      journeyJson(
        beginner: beginner,
        insider: insider,
        completed: completed,
        checkpoint: checkpoint,
        contentVersion: version,
      ),
    );
