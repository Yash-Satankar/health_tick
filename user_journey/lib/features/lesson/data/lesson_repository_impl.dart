import '../../../core/network/api_client.dart';
import '../domain/lesson.dart';
import 'lesson_dto.dart';

class LessonRemoteDataSource {
  LessonRemoteDataSource(this._api);

  final ApiClient _api;

  Future<Lesson> getLesson(String lessonId) => _api.get('/api/v1/lessons/$lessonId', parseLesson);

  Future<String> startAttempt(String lessonId) =>
      _api.post('/api/v1/lessons/$lessonId/attempts', (data) => asJsonMap(data)['attemptId'] as String);

  Future<AnswerResult> answer(String attemptId, String pageId, Map<String, Object> body) =>
      _api.put('/api/v1/attempts/$attemptId/answers/$pageId', parseAnswerResult, body: body);

  Future<LessonCompletion> complete(String attemptId) =>
      _api.post('/api/v1/attempts/$attemptId/complete', parseCompletion);

  Future<void> abandon(String attemptId) => _api.postNoContent('/api/v1/attempts/$attemptId/abandon');

  Future<bool> setSaved(String lessonId, bool saved) {
    bool parse(Object? data) => asJsonMap(data)['isSaved'] as bool;
    return saved
        ? _api.put('/api/v1/lessons/$lessonId/saved', parse)
        : _api.delete('/api/v1/lessons/$lessonId/saved', parse);
  }

  Future<void> sendFeedback(String lessonId, Map<String, Object> body) =>
      _api.post('/api/v1/lessons/$lessonId/feedback', (_) {}, body: body);
}

class LessonRepositoryImpl implements LessonRepository {
  LessonRepositoryImpl(this._remote);

  final LessonRemoteDataSource _remote;

  @override
  Future<Lesson> getLesson(String lessonId) => _remote.getLesson(lessonId);

  @override
  Future<String> startAttempt(String lessonId) => _remote.startAttempt(lessonId);

  @override
  Future<AnswerResult> submitChoice(String attemptId, String pageId, List<String> optionIds) =>
      _remote.answer(attemptId, pageId, {'optionIds': optionIds});

  @override
  Future<AnswerResult> submitText(String attemptId, String pageId, String text) =>
      _remote.answer(attemptId, pageId, {'text': text});

  @override
  Future<LessonCompletion> complete(String attemptId) => _remote.complete(attemptId);

  @override
  Future<void> abandon(String attemptId) => _remote.abandon(attemptId);

  @override
  Future<bool> setSaved(String lessonId, {required bool saved}) => _remote.setSaved(lessonId, saved);

  @override
  Future<void> sendFeedback(String lessonId, {required List<String> reasonIds, String? comment, String? pageId}) =>
      _remote.sendFeedback(lessonId, {
        'reasonIds': reasonIds,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
        'pageId': ?pageId,
      });
}
