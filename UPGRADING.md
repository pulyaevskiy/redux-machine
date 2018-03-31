## Upgrading from `0.1.x` to `1.0.0-beta.1`

In `1.0.0-beta.1` the `Store` class can now be used as a state machine as well,
therefore `StateMachine` class has been deprecated and will be removed in
one of the following beta releases, before stable `1.0.0`.

Following are the guidelines which should help upgrading from `0.1.x` versions.

### Replace `StateMachine` with `Store`

Use regular `StoreBuilder` instead of `StateMachineBuilder` to create an
instance of `Store` class.

### Reducers

The `MachineReducer` typedef is deprecated. Reducers need to be updated to use
regular `Reducer` signature. Usage of `ActionDispatcher` argument can be
replaced by the new `Action.next()` method:

```dart
/// Before:
MyState oldMachineReducer(MyState state, Action<void> action,
  ActionDispatcher dispatcher) {
  dispatcher(Actions.doFoo());
  return state.copyWith(someField: 'value');
}

/// After
MyState oldMachineReducer(MyState state, Action<void> action) {
  /// Instruct state store to dispatch `doFoo` action and pass `newState`
  /// as an input.
  final newState = state.copyWith(someField: 'value');
  return action.next(Actions.doFoo(), newState);
}
```

### Action builders

Any `ActionBuilder<Null>` or `ActionBuilder<void>` declaration needs to be
replaced with new `VoidActionBuilder` since `ActionBuilder` has been updated
to require non-empty payload. This was changed to allow better static analysis.

```dart
abstract class Actions {
  /// Before:
  static const push = const ActionBuilder<Null>('push');
  /// After:
  static const push = const VoidActionBuilder('push');
}
```

### Error handling

Subscribe to new `Store.errors` stream to report any unhandled errors.
If there is no active listener on that stream all errors are rethrown
synchronously by `Store.dispatch()`.
