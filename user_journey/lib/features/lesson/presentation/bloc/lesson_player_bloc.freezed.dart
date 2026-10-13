// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'lesson_player_bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LessonPlayerState implements DiagnosticableTreeMixin {

 LessonStatus get status; Lesson? get lesson; String? get attemptId; int get pageIndex; Map<String, PageAnswer> get answers; String? get showingFeedbackFor; AnswerFeedback? get feedback; int get hpCounter; bool get submitting; Failure? get inlineError; LessonCompletion? get completion; bool get isSaved; Failure? get loadFailure; bool get feedbackSubmitting; Failure? get feedbackError; LessonEffect? get effect; int get effectId;
/// Create a copy of LessonPlayerState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LessonPlayerStateCopyWith<LessonPlayerState> get copyWith => _$LessonPlayerStateCopyWithImpl<LessonPlayerState>(this as LessonPlayerState, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'LessonPlayerState'))
    ..add(DiagnosticsProperty('status', status))..add(DiagnosticsProperty('lesson', lesson))..add(DiagnosticsProperty('attemptId', attemptId))..add(DiagnosticsProperty('pageIndex', pageIndex))..add(DiagnosticsProperty('answers', answers))..add(DiagnosticsProperty('showingFeedbackFor', showingFeedbackFor))..add(DiagnosticsProperty('feedback', feedback))..add(DiagnosticsProperty('hpCounter', hpCounter))..add(DiagnosticsProperty('submitting', submitting))..add(DiagnosticsProperty('inlineError', inlineError))..add(DiagnosticsProperty('completion', completion))..add(DiagnosticsProperty('isSaved', isSaved))..add(DiagnosticsProperty('loadFailure', loadFailure))..add(DiagnosticsProperty('feedbackSubmitting', feedbackSubmitting))..add(DiagnosticsProperty('feedbackError', feedbackError))..add(DiagnosticsProperty('effect', effect))..add(DiagnosticsProperty('effectId', effectId));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LessonPlayerState&&(identical(other.status, status) || other.status == status)&&(identical(other.lesson, lesson) || other.lesson == lesson)&&(identical(other.attemptId, attemptId) || other.attemptId == attemptId)&&(identical(other.pageIndex, pageIndex) || other.pageIndex == pageIndex)&&const DeepCollectionEquality().equals(other.answers, answers)&&(identical(other.showingFeedbackFor, showingFeedbackFor) || other.showingFeedbackFor == showingFeedbackFor)&&(identical(other.feedback, feedback) || other.feedback == feedback)&&(identical(other.hpCounter, hpCounter) || other.hpCounter == hpCounter)&&(identical(other.submitting, submitting) || other.submitting == submitting)&&(identical(other.inlineError, inlineError) || other.inlineError == inlineError)&&(identical(other.completion, completion) || other.completion == completion)&&(identical(other.isSaved, isSaved) || other.isSaved == isSaved)&&(identical(other.loadFailure, loadFailure) || other.loadFailure == loadFailure)&&(identical(other.feedbackSubmitting, feedbackSubmitting) || other.feedbackSubmitting == feedbackSubmitting)&&(identical(other.feedbackError, feedbackError) || other.feedbackError == feedbackError)&&(identical(other.effect, effect) || other.effect == effect)&&(identical(other.effectId, effectId) || other.effectId == effectId));
}


@override
int get hashCode => Object.hash(runtimeType,status,lesson,attemptId,pageIndex,const DeepCollectionEquality().hash(answers),showingFeedbackFor,feedback,hpCounter,submitting,inlineError,completion,isSaved,loadFailure,feedbackSubmitting,feedbackError,effect,effectId);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'LessonPlayerState(status: $status, lesson: $lesson, attemptId: $attemptId, pageIndex: $pageIndex, answers: $answers, showingFeedbackFor: $showingFeedbackFor, feedback: $feedback, hpCounter: $hpCounter, submitting: $submitting, inlineError: $inlineError, completion: $completion, isSaved: $isSaved, loadFailure: $loadFailure, feedbackSubmitting: $feedbackSubmitting, feedbackError: $feedbackError, effect: $effect, effectId: $effectId)';
}


}

/// @nodoc
abstract mixin class $LessonPlayerStateCopyWith<$Res>  {
  factory $LessonPlayerStateCopyWith(LessonPlayerState value, $Res Function(LessonPlayerState) _then) = _$LessonPlayerStateCopyWithImpl;
@useResult
$Res call({
 LessonStatus status, Lesson? lesson, String? attemptId, int pageIndex, Map<String, PageAnswer> answers, String? showingFeedbackFor, AnswerFeedback? feedback, int hpCounter, bool submitting, Failure? inlineError, LessonCompletion? completion, bool isSaved, Failure? loadFailure, bool feedbackSubmitting, Failure? feedbackError, LessonEffect? effect, int effectId
});




}
/// @nodoc
class _$LessonPlayerStateCopyWithImpl<$Res>
    implements $LessonPlayerStateCopyWith<$Res> {
  _$LessonPlayerStateCopyWithImpl(this._self, this._then);

  final LessonPlayerState _self;
  final $Res Function(LessonPlayerState) _then;

/// Create a copy of LessonPlayerState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? lesson = freezed,Object? attemptId = freezed,Object? pageIndex = null,Object? answers = null,Object? showingFeedbackFor = freezed,Object? feedback = freezed,Object? hpCounter = null,Object? submitting = null,Object? inlineError = freezed,Object? completion = freezed,Object? isSaved = null,Object? loadFailure = freezed,Object? feedbackSubmitting = null,Object? feedbackError = freezed,Object? effect = freezed,Object? effectId = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LessonStatus,lesson: freezed == lesson ? _self.lesson : lesson // ignore: cast_nullable_to_non_nullable
as Lesson?,attemptId: freezed == attemptId ? _self.attemptId : attemptId // ignore: cast_nullable_to_non_nullable
as String?,pageIndex: null == pageIndex ? _self.pageIndex : pageIndex // ignore: cast_nullable_to_non_nullable
as int,answers: null == answers ? _self.answers : answers // ignore: cast_nullable_to_non_nullable
as Map<String, PageAnswer>,showingFeedbackFor: freezed == showingFeedbackFor ? _self.showingFeedbackFor : showingFeedbackFor // ignore: cast_nullable_to_non_nullable
as String?,feedback: freezed == feedback ? _self.feedback : feedback // ignore: cast_nullable_to_non_nullable
as AnswerFeedback?,hpCounter: null == hpCounter ? _self.hpCounter : hpCounter // ignore: cast_nullable_to_non_nullable
as int,submitting: null == submitting ? _self.submitting : submitting // ignore: cast_nullable_to_non_nullable
as bool,inlineError: freezed == inlineError ? _self.inlineError : inlineError // ignore: cast_nullable_to_non_nullable
as Failure?,completion: freezed == completion ? _self.completion : completion // ignore: cast_nullable_to_non_nullable
as LessonCompletion?,isSaved: null == isSaved ? _self.isSaved : isSaved // ignore: cast_nullable_to_non_nullable
as bool,loadFailure: freezed == loadFailure ? _self.loadFailure : loadFailure // ignore: cast_nullable_to_non_nullable
as Failure?,feedbackSubmitting: null == feedbackSubmitting ? _self.feedbackSubmitting : feedbackSubmitting // ignore: cast_nullable_to_non_nullable
as bool,feedbackError: freezed == feedbackError ? _self.feedbackError : feedbackError // ignore: cast_nullable_to_non_nullable
as Failure?,effect: freezed == effect ? _self.effect : effect // ignore: cast_nullable_to_non_nullable
as LessonEffect?,effectId: null == effectId ? _self.effectId : effectId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [LessonPlayerState].
extension LessonPlayerStatePatterns on LessonPlayerState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LessonPlayerState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LessonPlayerState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LessonPlayerState value)  $default,){
final _that = this;
switch (_that) {
case _LessonPlayerState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LessonPlayerState value)?  $default,){
final _that = this;
switch (_that) {
case _LessonPlayerState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( LessonStatus status,  Lesson? lesson,  String? attemptId,  int pageIndex,  Map<String, PageAnswer> answers,  String? showingFeedbackFor,  AnswerFeedback? feedback,  int hpCounter,  bool submitting,  Failure? inlineError,  LessonCompletion? completion,  bool isSaved,  Failure? loadFailure,  bool feedbackSubmitting,  Failure? feedbackError,  LessonEffect? effect,  int effectId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LessonPlayerState() when $default != null:
return $default(_that.status,_that.lesson,_that.attemptId,_that.pageIndex,_that.answers,_that.showingFeedbackFor,_that.feedback,_that.hpCounter,_that.submitting,_that.inlineError,_that.completion,_that.isSaved,_that.loadFailure,_that.feedbackSubmitting,_that.feedbackError,_that.effect,_that.effectId);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( LessonStatus status,  Lesson? lesson,  String? attemptId,  int pageIndex,  Map<String, PageAnswer> answers,  String? showingFeedbackFor,  AnswerFeedback? feedback,  int hpCounter,  bool submitting,  Failure? inlineError,  LessonCompletion? completion,  bool isSaved,  Failure? loadFailure,  bool feedbackSubmitting,  Failure? feedbackError,  LessonEffect? effect,  int effectId)  $default,) {final _that = this;
switch (_that) {
case _LessonPlayerState():
return $default(_that.status,_that.lesson,_that.attemptId,_that.pageIndex,_that.answers,_that.showingFeedbackFor,_that.feedback,_that.hpCounter,_that.submitting,_that.inlineError,_that.completion,_that.isSaved,_that.loadFailure,_that.feedbackSubmitting,_that.feedbackError,_that.effect,_that.effectId);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( LessonStatus status,  Lesson? lesson,  String? attemptId,  int pageIndex,  Map<String, PageAnswer> answers,  String? showingFeedbackFor,  AnswerFeedback? feedback,  int hpCounter,  bool submitting,  Failure? inlineError,  LessonCompletion? completion,  bool isSaved,  Failure? loadFailure,  bool feedbackSubmitting,  Failure? feedbackError,  LessonEffect? effect,  int effectId)?  $default,) {final _that = this;
switch (_that) {
case _LessonPlayerState() when $default != null:
return $default(_that.status,_that.lesson,_that.attemptId,_that.pageIndex,_that.answers,_that.showingFeedbackFor,_that.feedback,_that.hpCounter,_that.submitting,_that.inlineError,_that.completion,_that.isSaved,_that.loadFailure,_that.feedbackSubmitting,_that.feedbackError,_that.effect,_that.effectId);case _:
  return null;

}
}

}

/// @nodoc


class _LessonPlayerState extends LessonPlayerState with DiagnosticableTreeMixin {
  const _LessonPlayerState({this.status = LessonStatus.loading, this.lesson, this.attemptId, this.pageIndex = 0, final  Map<String, PageAnswer> answers = const <String, PageAnswer>{}, this.showingFeedbackFor, this.feedback, this.hpCounter = 0, this.submitting = false, this.inlineError, this.completion, this.isSaved = false, this.loadFailure, this.feedbackSubmitting = false, this.feedbackError, this.effect, this.effectId = 0}): _answers = answers,super._();
  

@override@JsonKey() final  LessonStatus status;
@override final  Lesson? lesson;
@override final  String? attemptId;
@override@JsonKey() final  int pageIndex;
 final  Map<String, PageAnswer> _answers;
@override@JsonKey() Map<String, PageAnswer> get answers {
  if (_answers is EqualUnmodifiableMapView) return _answers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_answers);
}

@override final  String? showingFeedbackFor;
@override final  AnswerFeedback? feedback;
@override@JsonKey() final  int hpCounter;
@override@JsonKey() final  bool submitting;
@override final  Failure? inlineError;
@override final  LessonCompletion? completion;
@override@JsonKey() final  bool isSaved;
@override final  Failure? loadFailure;
@override@JsonKey() final  bool feedbackSubmitting;
@override final  Failure? feedbackError;
@override final  LessonEffect? effect;
@override@JsonKey() final  int effectId;

/// Create a copy of LessonPlayerState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LessonPlayerStateCopyWith<_LessonPlayerState> get copyWith => __$LessonPlayerStateCopyWithImpl<_LessonPlayerState>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'LessonPlayerState'))
    ..add(DiagnosticsProperty('status', status))..add(DiagnosticsProperty('lesson', lesson))..add(DiagnosticsProperty('attemptId', attemptId))..add(DiagnosticsProperty('pageIndex', pageIndex))..add(DiagnosticsProperty('answers', answers))..add(DiagnosticsProperty('showingFeedbackFor', showingFeedbackFor))..add(DiagnosticsProperty('feedback', feedback))..add(DiagnosticsProperty('hpCounter', hpCounter))..add(DiagnosticsProperty('submitting', submitting))..add(DiagnosticsProperty('inlineError', inlineError))..add(DiagnosticsProperty('completion', completion))..add(DiagnosticsProperty('isSaved', isSaved))..add(DiagnosticsProperty('loadFailure', loadFailure))..add(DiagnosticsProperty('feedbackSubmitting', feedbackSubmitting))..add(DiagnosticsProperty('feedbackError', feedbackError))..add(DiagnosticsProperty('effect', effect))..add(DiagnosticsProperty('effectId', effectId));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LessonPlayerState&&(identical(other.status, status) || other.status == status)&&(identical(other.lesson, lesson) || other.lesson == lesson)&&(identical(other.attemptId, attemptId) || other.attemptId == attemptId)&&(identical(other.pageIndex, pageIndex) || other.pageIndex == pageIndex)&&const DeepCollectionEquality().equals(other._answers, _answers)&&(identical(other.showingFeedbackFor, showingFeedbackFor) || other.showingFeedbackFor == showingFeedbackFor)&&(identical(other.feedback, feedback) || other.feedback == feedback)&&(identical(other.hpCounter, hpCounter) || other.hpCounter == hpCounter)&&(identical(other.submitting, submitting) || other.submitting == submitting)&&(identical(other.inlineError, inlineError) || other.inlineError == inlineError)&&(identical(other.completion, completion) || other.completion == completion)&&(identical(other.isSaved, isSaved) || other.isSaved == isSaved)&&(identical(other.loadFailure, loadFailure) || other.loadFailure == loadFailure)&&(identical(other.feedbackSubmitting, feedbackSubmitting) || other.feedbackSubmitting == feedbackSubmitting)&&(identical(other.feedbackError, feedbackError) || other.feedbackError == feedbackError)&&(identical(other.effect, effect) || other.effect == effect)&&(identical(other.effectId, effectId) || other.effectId == effectId));
}


@override
int get hashCode => Object.hash(runtimeType,status,lesson,attemptId,pageIndex,const DeepCollectionEquality().hash(_answers),showingFeedbackFor,feedback,hpCounter,submitting,inlineError,completion,isSaved,loadFailure,feedbackSubmitting,feedbackError,effect,effectId);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'LessonPlayerState(status: $status, lesson: $lesson, attemptId: $attemptId, pageIndex: $pageIndex, answers: $answers, showingFeedbackFor: $showingFeedbackFor, feedback: $feedback, hpCounter: $hpCounter, submitting: $submitting, inlineError: $inlineError, completion: $completion, isSaved: $isSaved, loadFailure: $loadFailure, feedbackSubmitting: $feedbackSubmitting, feedbackError: $feedbackError, effect: $effect, effectId: $effectId)';
}


}

/// @nodoc
abstract mixin class _$LessonPlayerStateCopyWith<$Res> implements $LessonPlayerStateCopyWith<$Res> {
  factory _$LessonPlayerStateCopyWith(_LessonPlayerState value, $Res Function(_LessonPlayerState) _then) = __$LessonPlayerStateCopyWithImpl;
@override @useResult
$Res call({
 LessonStatus status, Lesson? lesson, String? attemptId, int pageIndex, Map<String, PageAnswer> answers, String? showingFeedbackFor, AnswerFeedback? feedback, int hpCounter, bool submitting, Failure? inlineError, LessonCompletion? completion, bool isSaved, Failure? loadFailure, bool feedbackSubmitting, Failure? feedbackError, LessonEffect? effect, int effectId
});




}
/// @nodoc
class __$LessonPlayerStateCopyWithImpl<$Res>
    implements _$LessonPlayerStateCopyWith<$Res> {
  __$LessonPlayerStateCopyWithImpl(this._self, this._then);

  final _LessonPlayerState _self;
  final $Res Function(_LessonPlayerState) _then;

/// Create a copy of LessonPlayerState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? lesson = freezed,Object? attemptId = freezed,Object? pageIndex = null,Object? answers = null,Object? showingFeedbackFor = freezed,Object? feedback = freezed,Object? hpCounter = null,Object? submitting = null,Object? inlineError = freezed,Object? completion = freezed,Object? isSaved = null,Object? loadFailure = freezed,Object? feedbackSubmitting = null,Object? feedbackError = freezed,Object? effect = freezed,Object? effectId = null,}) {
  return _then(_LessonPlayerState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LessonStatus,lesson: freezed == lesson ? _self.lesson : lesson // ignore: cast_nullable_to_non_nullable
as Lesson?,attemptId: freezed == attemptId ? _self.attemptId : attemptId // ignore: cast_nullable_to_non_nullable
as String?,pageIndex: null == pageIndex ? _self.pageIndex : pageIndex // ignore: cast_nullable_to_non_nullable
as int,answers: null == answers ? _self._answers : answers // ignore: cast_nullable_to_non_nullable
as Map<String, PageAnswer>,showingFeedbackFor: freezed == showingFeedbackFor ? _self.showingFeedbackFor : showingFeedbackFor // ignore: cast_nullable_to_non_nullable
as String?,feedback: freezed == feedback ? _self.feedback : feedback // ignore: cast_nullable_to_non_nullable
as AnswerFeedback?,hpCounter: null == hpCounter ? _self.hpCounter : hpCounter // ignore: cast_nullable_to_non_nullable
as int,submitting: null == submitting ? _self.submitting : submitting // ignore: cast_nullable_to_non_nullable
as bool,inlineError: freezed == inlineError ? _self.inlineError : inlineError // ignore: cast_nullable_to_non_nullable
as Failure?,completion: freezed == completion ? _self.completion : completion // ignore: cast_nullable_to_non_nullable
as LessonCompletion?,isSaved: null == isSaved ? _self.isSaved : isSaved // ignore: cast_nullable_to_non_nullable
as bool,loadFailure: freezed == loadFailure ? _self.loadFailure : loadFailure // ignore: cast_nullable_to_non_nullable
as Failure?,feedbackSubmitting: null == feedbackSubmitting ? _self.feedbackSubmitting : feedbackSubmitting // ignore: cast_nullable_to_non_nullable
as bool,feedbackError: freezed == feedbackError ? _self.feedbackError : feedbackError // ignore: cast_nullable_to_non_nullable
as Failure?,effect: freezed == effect ? _self.effect : effect // ignore: cast_nullable_to_non_nullable
as LessonEffect?,effectId: null == effectId ? _self.effectId : effectId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
