// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'base_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BaseEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BaseEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'BaseEvent()';
}


}

/// @nodoc
class $BaseEventCopyWith<$Res>  {
$BaseEventCopyWith(BaseEvent _, $Res Function(BaseEvent) __);
}


/// Adds pattern-matching-related methods to [BaseEvent].
extension BaseEventPatterns on BaseEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( AppStarted value)?  appStarted,TResult Function( GenericEvent value)?  generic,required TResult orElse(),}){
final _that = this;
switch (_that) {
case AppStarted() when appStarted != null:
return appStarted(_that);case GenericEvent() when generic != null:
return generic(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( AppStarted value)  appStarted,required TResult Function( GenericEvent value)  generic,}){
final _that = this;
switch (_that) {
case AppStarted():
return appStarted(_that);case GenericEvent():
return generic(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( AppStarted value)?  appStarted,TResult? Function( GenericEvent value)?  generic,}){
final _that = this;
switch (_that) {
case AppStarted() when appStarted != null:
return appStarted(_that);case GenericEvent() when generic != null:
return generic(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  appStarted,TResult Function( String type,  dynamic payload)?  generic,required TResult orElse(),}) {final _that = this;
switch (_that) {
case AppStarted() when appStarted != null:
return appStarted();case GenericEvent() when generic != null:
return generic(_that.type,_that.payload);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  appStarted,required TResult Function( String type,  dynamic payload)  generic,}) {final _that = this;
switch (_that) {
case AppStarted():
return appStarted();case GenericEvent():
return generic(_that.type,_that.payload);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  appStarted,TResult? Function( String type,  dynamic payload)?  generic,}) {final _that = this;
switch (_that) {
case AppStarted() when appStarted != null:
return appStarted();case GenericEvent() when generic != null:
return generic(_that.type,_that.payload);case _:
  return null;

}
}

}

/// @nodoc


class AppStarted implements BaseEvent {
  const AppStarted();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppStarted);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'BaseEvent.appStarted()';
}


}




/// @nodoc


class GenericEvent implements BaseEvent {
  const GenericEvent(this.type, {this.payload});
  

 final  String type;
 final  dynamic payload;

/// Create a copy of BaseEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GenericEventCopyWith<GenericEvent> get copyWith => _$GenericEventCopyWithImpl<GenericEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GenericEvent&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other.payload, payload));
}


@override
int get hashCode => Object.hash(runtimeType,type,const DeepCollectionEquality().hash(payload));

@override
String toString() {
  return 'BaseEvent.generic(type: $type, payload: $payload)';
}


}

/// @nodoc
abstract mixin class $GenericEventCopyWith<$Res> implements $BaseEventCopyWith<$Res> {
  factory $GenericEventCopyWith(GenericEvent value, $Res Function(GenericEvent) _then) = _$GenericEventCopyWithImpl;
@useResult
$Res call({
 String type, dynamic payload
});




}
/// @nodoc
class _$GenericEventCopyWithImpl<$Res>
    implements $GenericEventCopyWith<$Res> {
  _$GenericEventCopyWithImpl(this._self, this._then);

  final GenericEvent _self;
  final $Res Function(GenericEvent) _then;

/// Create a copy of BaseEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? type = null,Object? payload = freezed,}) {
  return _then(GenericEvent(
null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,payload: freezed == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as dynamic,
  ));
}


}

// dart format on
