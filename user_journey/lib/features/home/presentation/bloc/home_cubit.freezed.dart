// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'home_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$HomeState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HomeState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'HomeState()';
}


}

/// @nodoc
class $HomeStateCopyWith<$Res>  {
$HomeStateCopyWith(HomeState _, $Res Function(HomeState) __);
}


/// Adds pattern-matching-related methods to [HomeState].
extension HomeStatePatterns on HomeState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( HomeLoading value)?  loading,TResult Function( HomeReady value)?  ready,TResult Function( HomeFailure value)?  failure,required TResult orElse(),}){
final _that = this;
switch (_that) {
case HomeLoading() when loading != null:
return loading(_that);case HomeReady() when ready != null:
return ready(_that);case HomeFailure() when failure != null:
return failure(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( HomeLoading value)  loading,required TResult Function( HomeReady value)  ready,required TResult Function( HomeFailure value)  failure,}){
final _that = this;
switch (_that) {
case HomeLoading():
return loading(_that);case HomeReady():
return ready(_that);case HomeFailure():
return failure(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( HomeLoading value)?  loading,TResult? Function( HomeReady value)?  ready,TResult? Function( HomeFailure value)?  failure,}){
final _that = this;
switch (_that) {
case HomeLoading() when loading != null:
return loading(_that);case HomeReady() when ready != null:
return ready(_that);case HomeFailure() when failure != null:
return failure(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  loading,TResult Function( HomeData data,  Failure? refreshError,  int errorId)?  ready,TResult Function( Failure failure)?  failure,required TResult orElse(),}) {final _that = this;
switch (_that) {
case HomeLoading() when loading != null:
return loading();case HomeReady() when ready != null:
return ready(_that.data,_that.refreshError,_that.errorId);case HomeFailure() when failure != null:
return failure(_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  loading,required TResult Function( HomeData data,  Failure? refreshError,  int errorId)  ready,required TResult Function( Failure failure)  failure,}) {final _that = this;
switch (_that) {
case HomeLoading():
return loading();case HomeReady():
return ready(_that.data,_that.refreshError,_that.errorId);case HomeFailure():
return failure(_that.failure);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  loading,TResult? Function( HomeData data,  Failure? refreshError,  int errorId)?  ready,TResult? Function( Failure failure)?  failure,}) {final _that = this;
switch (_that) {
case HomeLoading() when loading != null:
return loading();case HomeReady() when ready != null:
return ready(_that.data,_that.refreshError,_that.errorId);case HomeFailure() when failure != null:
return failure(_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class HomeLoading implements HomeState {
  const HomeLoading();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HomeLoading);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'HomeState.loading()';
}


}




/// @nodoc


class HomeReady implements HomeState {
  const HomeReady(this.data, {this.refreshError, this.errorId = 0});
  

 final  HomeData data;
 final  Failure? refreshError;
@JsonKey() final  int errorId;

/// Create a copy of HomeState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HomeReadyCopyWith<HomeReady> get copyWith => _$HomeReadyCopyWithImpl<HomeReady>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HomeReady&&(identical(other.data, data) || other.data == data)&&(identical(other.refreshError, refreshError) || other.refreshError == refreshError)&&(identical(other.errorId, errorId) || other.errorId == errorId));
}


@override
int get hashCode => Object.hash(runtimeType,data,refreshError,errorId);

@override
String toString() {
  return 'HomeState.ready(data: $data, refreshError: $refreshError, errorId: $errorId)';
}


}

/// @nodoc
abstract mixin class $HomeReadyCopyWith<$Res> implements $HomeStateCopyWith<$Res> {
  factory $HomeReadyCopyWith(HomeReady value, $Res Function(HomeReady) _then) = _$HomeReadyCopyWithImpl;
@useResult
$Res call({
 HomeData data, Failure? refreshError, int errorId
});




}
/// @nodoc
class _$HomeReadyCopyWithImpl<$Res>
    implements $HomeReadyCopyWith<$Res> {
  _$HomeReadyCopyWithImpl(this._self, this._then);

  final HomeReady _self;
  final $Res Function(HomeReady) _then;

/// Create a copy of HomeState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? data = null,Object? refreshError = freezed,Object? errorId = null,}) {
  return _then(HomeReady(
null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as HomeData,refreshError: freezed == refreshError ? _self.refreshError : refreshError // ignore: cast_nullable_to_non_nullable
as Failure?,errorId: null == errorId ? _self.errorId : errorId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class HomeFailure implements HomeState {
  const HomeFailure(this.failure);
  

 final  Failure failure;

/// Create a copy of HomeState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HomeFailureCopyWith<HomeFailure> get copyWith => _$HomeFailureCopyWithImpl<HomeFailure>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HomeFailure&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,failure);

@override
String toString() {
  return 'HomeState.failure(failure: $failure)';
}


}

/// @nodoc
abstract mixin class $HomeFailureCopyWith<$Res> implements $HomeStateCopyWith<$Res> {
  factory $HomeFailureCopyWith(HomeFailure value, $Res Function(HomeFailure) _then) = _$HomeFailureCopyWithImpl;
@useResult
$Res call({
 Failure failure
});




}
/// @nodoc
class _$HomeFailureCopyWithImpl<$Res>
    implements $HomeFailureCopyWith<$Res> {
  _$HomeFailureCopyWithImpl(this._self, this._then);

  final HomeFailure _self;
  final $Res Function(HomeFailure) _then;

/// Create a copy of HomeState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? failure = null,}) {
  return _then(HomeFailure(
null == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure,
  ));
}


}

// dart format on
