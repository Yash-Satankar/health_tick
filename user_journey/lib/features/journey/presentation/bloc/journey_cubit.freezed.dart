// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'journey_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$JourneyState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JourneyState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'JourneyState()';
}


}

/// @nodoc
class $JourneyStateCopyWith<$Res>  {
$JourneyStateCopyWith(JourneyState _, $Res Function(JourneyState) __);
}


/// Adds pattern-matching-related methods to [JourneyState].
extension JourneyStatePatterns on JourneyState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( JourneyLoading value)?  loading,TResult Function( JourneyFailure value)?  failure,TResult Function( JourneyLoaded value)?  loaded,required TResult orElse(),}){
final _that = this;
switch (_that) {
case JourneyLoading() when loading != null:
return loading(_that);case JourneyFailure() when failure != null:
return failure(_that);case JourneyLoaded() when loaded != null:
return loaded(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( JourneyLoading value)  loading,required TResult Function( JourneyFailure value)  failure,required TResult Function( JourneyLoaded value)  loaded,}){
final _that = this;
switch (_that) {
case JourneyLoading():
return loading(_that);case JourneyFailure():
return failure(_that);case JourneyLoaded():
return loaded(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( JourneyLoading value)?  loading,TResult? Function( JourneyFailure value)?  failure,TResult? Function( JourneyLoaded value)?  loaded,}){
final _that = this;
switch (_that) {
case JourneyLoading() when loading != null:
return loading(_that);case JourneyFailure() when failure != null:
return failure(_that);case JourneyLoaded() when loaded != null:
return loaded(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  loading,TResult Function( Failure failure)?  failure,TResult Function( Journey journey,  String? selectedNodeId,  JourneyActivity activity,  Failure? transientError,  int errorId,  int scrollToTopId,  String? pulseNodeId)?  loaded,required TResult orElse(),}) {final _that = this;
switch (_that) {
case JourneyLoading() when loading != null:
return loading();case JourneyFailure() when failure != null:
return failure(_that.failure);case JourneyLoaded() when loaded != null:
return loaded(_that.journey,_that.selectedNodeId,_that.activity,_that.transientError,_that.errorId,_that.scrollToTopId,_that.pulseNodeId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  loading,required TResult Function( Failure failure)  failure,required TResult Function( Journey journey,  String? selectedNodeId,  JourneyActivity activity,  Failure? transientError,  int errorId,  int scrollToTopId,  String? pulseNodeId)  loaded,}) {final _that = this;
switch (_that) {
case JourneyLoading():
return loading();case JourneyFailure():
return failure(_that.failure);case JourneyLoaded():
return loaded(_that.journey,_that.selectedNodeId,_that.activity,_that.transientError,_that.errorId,_that.scrollToTopId,_that.pulseNodeId);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  loading,TResult? Function( Failure failure)?  failure,TResult? Function( Journey journey,  String? selectedNodeId,  JourneyActivity activity,  Failure? transientError,  int errorId,  int scrollToTopId,  String? pulseNodeId)?  loaded,}) {final _that = this;
switch (_that) {
case JourneyLoading() when loading != null:
return loading();case JourneyFailure() when failure != null:
return failure(_that.failure);case JourneyLoaded() when loaded != null:
return loaded(_that.journey,_that.selectedNodeId,_that.activity,_that.transientError,_that.errorId,_that.scrollToTopId,_that.pulseNodeId);case _:
  return null;

}
}

}

/// @nodoc


class JourneyLoading extends JourneyState {
  const JourneyLoading(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JourneyLoading);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'JourneyState.loading()';
}


}




/// @nodoc


class JourneyFailure extends JourneyState {
  const JourneyFailure(this.failure): super._();
  

 final  Failure failure;

/// Create a copy of JourneyState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JourneyFailureCopyWith<JourneyFailure> get copyWith => _$JourneyFailureCopyWithImpl<JourneyFailure>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JourneyFailure&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,failure);

@override
String toString() {
  return 'JourneyState.failure(failure: $failure)';
}


}

/// @nodoc
abstract mixin class $JourneyFailureCopyWith<$Res> implements $JourneyStateCopyWith<$Res> {
  factory $JourneyFailureCopyWith(JourneyFailure value, $Res Function(JourneyFailure) _then) = _$JourneyFailureCopyWithImpl;
@useResult
$Res call({
 Failure failure
});




}
/// @nodoc
class _$JourneyFailureCopyWithImpl<$Res>
    implements $JourneyFailureCopyWith<$Res> {
  _$JourneyFailureCopyWithImpl(this._self, this._then);

  final JourneyFailure _self;
  final $Res Function(JourneyFailure) _then;

/// Create a copy of JourneyState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? failure = null,}) {
  return _then(JourneyFailure(
null == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure,
  ));
}


}

/// @nodoc


class JourneyLoaded extends JourneyState {
  const JourneyLoaded({required this.journey, this.selectedNodeId, this.activity = JourneyActivity.idle, this.transientError, this.errorId = 0, this.scrollToTopId = 0, this.pulseNodeId}): super._();
  

 final  Journey journey;
 final  String? selectedNodeId;
@JsonKey() final  JourneyActivity activity;
 final  Failure? transientError;
@JsonKey() final  int errorId;
@JsonKey() final  int scrollToTopId;
 final  String? pulseNodeId;

/// Create a copy of JourneyState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JourneyLoadedCopyWith<JourneyLoaded> get copyWith => _$JourneyLoadedCopyWithImpl<JourneyLoaded>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JourneyLoaded&&(identical(other.journey, journey) || other.journey == journey)&&(identical(other.selectedNodeId, selectedNodeId) || other.selectedNodeId == selectedNodeId)&&(identical(other.activity, activity) || other.activity == activity)&&(identical(other.transientError, transientError) || other.transientError == transientError)&&(identical(other.errorId, errorId) || other.errorId == errorId)&&(identical(other.scrollToTopId, scrollToTopId) || other.scrollToTopId == scrollToTopId)&&(identical(other.pulseNodeId, pulseNodeId) || other.pulseNodeId == pulseNodeId));
}


@override
int get hashCode => Object.hash(runtimeType,journey,selectedNodeId,activity,transientError,errorId,scrollToTopId,pulseNodeId);

@override
String toString() {
  return 'JourneyState.loaded(journey: $journey, selectedNodeId: $selectedNodeId, activity: $activity, transientError: $transientError, errorId: $errorId, scrollToTopId: $scrollToTopId, pulseNodeId: $pulseNodeId)';
}


}

/// @nodoc
abstract mixin class $JourneyLoadedCopyWith<$Res> implements $JourneyStateCopyWith<$Res> {
  factory $JourneyLoadedCopyWith(JourneyLoaded value, $Res Function(JourneyLoaded) _then) = _$JourneyLoadedCopyWithImpl;
@useResult
$Res call({
 Journey journey, String? selectedNodeId, JourneyActivity activity, Failure? transientError, int errorId, int scrollToTopId, String? pulseNodeId
});




}
/// @nodoc
class _$JourneyLoadedCopyWithImpl<$Res>
    implements $JourneyLoadedCopyWith<$Res> {
  _$JourneyLoadedCopyWithImpl(this._self, this._then);

  final JourneyLoaded _self;
  final $Res Function(JourneyLoaded) _then;

/// Create a copy of JourneyState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? journey = null,Object? selectedNodeId = freezed,Object? activity = null,Object? transientError = freezed,Object? errorId = null,Object? scrollToTopId = null,Object? pulseNodeId = freezed,}) {
  return _then(JourneyLoaded(
journey: null == journey ? _self.journey : journey // ignore: cast_nullable_to_non_nullable
as Journey,selectedNodeId: freezed == selectedNodeId ? _self.selectedNodeId : selectedNodeId // ignore: cast_nullable_to_non_nullable
as String?,activity: null == activity ? _self.activity : activity // ignore: cast_nullable_to_non_nullable
as JourneyActivity,transientError: freezed == transientError ? _self.transientError : transientError // ignore: cast_nullable_to_non_nullable
as Failure?,errorId: null == errorId ? _self.errorId : errorId // ignore: cast_nullable_to_non_nullable
as int,scrollToTopId: null == scrollToTopId ? _self.scrollToTopId : scrollToTopId // ignore: cast_nullable_to_non_nullable
as int,pulseNodeId: freezed == pulseNodeId ? _self.pulseNodeId : pulseNodeId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
