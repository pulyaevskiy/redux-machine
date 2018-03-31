## 1.0.0-dev.2.0 (Unreleased)

- Added: `Action.next()` as a substitute to existing `MachineState.nextAction`.
    The regular `Store` class now also supports behavior of `StateMachine`,
    which makes `StateMachine` obsolete (will be removed before stable release).
- Deprecated: `StateMachine` and related classes
    (`MachineState`, `StateMachineBuilder`). Regular `Store` class can now be
    used as a state machine.

## 1.0.0-dev.1.0

This version is designed to work with Dart 2 and includes many changes to
provide better static analysis in most cases.

- Breaking: Depends on Dart SDK 2.0.0-dev
- Breaking: Removed deprecated `ReduxMachine` and related classes.
- Breaking: removed `onError` handler on `StoreBuilder` and `StateMachineBuilder`
    Unhandled errors from reducers are propagated to the new `Store.errors`
    stream if there is an active listener on it. If there is no active listener
    then errors are simply rethrown synchronously.
- Breaking: StateMachine now requires state objects to extend `MachineState`
    base class. See documentation for more details on how to use it.
- Breaking: Removed `ActionDispatcher`, `StateMachineReducer` interfaces.
    StateMachine uses regular `Reducer` interface now.
- Breaking: Removed `StoreErrorHandler` definition.
- Breaking: `ActionBuilder.call` changed `payload` argument from optional to
  required. Use new `VoidActionBuilder` for actions without any payload.
- Fixed: strong mode issues with Dart 2.
- Fixed: stack trace propagation in case of errors originated in reducers.
- Experimental: `AsyncAction` which allows dispatching code to know when it
  completes and if there was an error. Corresponding `AsyncActionBuilder` and
  `AsyncVoidActionBuilder` were introduced as well.

## 0.1.2

- Added `onError` argument to `StoreBuilder` and `StateMachineBuilder`.
- Fixed: don't swallow errors in action dispatch flow.
- Removed `StoreError` class.

## 0.1.1

- Added type argument to `StoreEvent` for the action payload type for
  better static analysis.
- Added `store` field to `StoreEvent` which contains reference to
  the state `Store` (or `StateMachine`) which produced that event.
- Added `Store.changesFor` to allow listening for changes on a part
  of the application state.

## 0.1.0

- Deprecated `ReduxMachine` implementation in favor of new
  `StateMachine` class.
- Added separate Redux `Store` implementation which can be used on
  its own. New `StateMachine` uses `Store` internally for state
  management.
- Updated readme with some details on side-effects handling in this
  library.

## 0.0.1

- Initial version, created by Stagehand
