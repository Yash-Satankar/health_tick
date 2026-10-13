// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_config_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AppConfigState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppConfigState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AppConfigState()';
}


}

/// @nodoc
class $AppConfigStateCopyWith<$Res>  {
$AppConfigStateCopyWith(AppConfigState _, $Res Function(AppConfigState) __);
}


/// Adds pattern-matching-related methods to [AppConfigState].
extension AppConfigStatePatterns on AppConfigState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( AppConfigLoading value)?  loading,TResult Function( AppConfigReady value)?  ready,TResult Function( AppConfigFailure value)?  failure,required TResult orElse(),}){
final _that = this;
switch (_that) {
case AppConfigLoading() when loading != null:
return loading(_that);case AppConfigReady() when ready != null:
return ready(_that);case AppConfigFailure() when failure != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( AppConfigLoading value)  loading,required TResult Function( AppConfigReady value)  ready,required TResult Function( AppConfigFailure value)  failure,}){
final _that = this;
switch (_that) {
case AppConfigLoading():
return loading(_that);case AppConfigReady():
return ready(_that);case AppConfigFailure():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( AppConfigLoading value)?  loading,TResult? Function( AppConfigReady value)?  ready,TResult? Function( AppConfigFailure value)?  failure,}){
final _that = this;
switch (_that) {
case AppConfigLoading() when loading != null:
return loading(_that);case AppConfigReady() when ready != null:
return ready(_that);case AppConfigFailure() when failure != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  loading,TResult Function( Bootstrap bootstrap)?  ready,TResult Function( Failure failure)?  failure,required TResult orElse(),}) {final _that = this;
switch (_that) {
case AppConfigLoading() when loading != null:
return loading();case AppConfigReady() when ready != null:
return ready(_that.bootstrap);case AppConfigFailure() when failure != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  loading,required TResult Function( Bootstrap bootstrap)  ready,required TResult Function( Failure failure)  failure,}) {final _that = this;
switch (_that) {
case AppConfigLoading():
return loading();case AppConfigReady():
return ready(_that.bootstrap);case AppConfigFailure():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  loading,TResult? Function( Bootstrap bootstrap)?  ready,TResult? Function( Failure failure)?  failure,}) {final _that = this;
switch (_that) {
case AppConfigLoading() when loading != null:
return loading();case AppConfigReady() when ready != null:
return ready(_that.bootstrap);case AppConfigFailure() when failure != null:
return failure(_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class AppConfigLoading extends AppConfigState {
  const AppConfigLoading(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppConfigLoading);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AppConfigState.loading()';
}


}




/// @nodoc


class AppConfigReady extends AppConfigState {
  const AppConfigReady(this.bootstrap): super._();
  

 final  Bootstrap bootstrap;

/// Create a copy of AppConfigState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppConfigReadyCopyWith<AppConfigReady> get copyWith => _$AppConfigReadyCopyWithImpl<AppConfigReady>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppConfigReady&&(identical(other.bootstrap, bootstrap) || other.bootstrap == bootstrap));
}


@override
int get hashCode => Object.hash(runtimeType,bootstrap);

@override
String toString() {
  return 'AppConfigState.ready(bootstrap: $bootstrap)';
}


}

/// @nodoc
abstract mixin class $AppConfigReadyCopyWith<$Res> implements $AppConfigStateCopyWith<$Res> {
  factory $AppConfigReadyCopyWith(AppConfigReady value, $Res Function(AppConfigReady) _then) = _$AppConfigReadyCopyWithImpl;
@useResult
$Res call({
 Bootstrap bootstrap
});




}
/// @nodoc
class _$AppConfigReadyCopyWithImpl<$Res>
    implements $AppConfigReadyCopyWith<$Res> {
  _$AppConfigReadyCopyWithImpl(this._self, this._then);

  final AppConfigReady _self;
  final $Res Function(AppConfigReady) _then;

/// Create a copy of AppConfigState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? bootstrap = null,}) {
  return _then(AppConfigReady(
null == bootstrap ? _self.bootstrap : bootstrap // ignore: cast_nullable_to_non_nullable
as Bootstrap,
  ));
}


}

/// @nodoc


class AppConfigFailure extends AppConfigState {
  const AppConfigFailure(this.failure): super._();
  

 final  Failure failure;

/// Create a copy of AppConfigState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppConfigFailureCopyWith<AppConfigFailure> get copyWith => _$AppConfigFailureCopyWithImpl<AppConfigFailure>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppConfigFailure&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,failure);

@override
String toString() {
  return 'AppConfigState.failure(failure: $failure)';
}


}

/// @nodoc
abstract mixin class $AppConfigFailureCopyWith<$Res> implements $AppConfigStateCopyWith<$Res> {
  factory $AppConfigFailureCopyWith(AppConfigFailure value, $Res Function(AppConfigFailure) _then) = _$AppConfigFailureCopyWithImpl;
@useResult
$Res call({
 Failure failure
});




}
/// @nodoc
class _$AppConfigFailureCopyWithImpl<$Res>
    implements $AppConfigFailureCopyWith<$Res> {
  _$AppConfigFailureCopyWithImpl(this._self, this._then);

  final AppConfigFailure _self;
  final $Res Function(AppConfigFailure) _then;

/// Create a copy of AppConfigState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? failure = null,}) {
  return _then(AppConfigFailure(
null == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as Failure,
  ));
}


}

// dart format on
