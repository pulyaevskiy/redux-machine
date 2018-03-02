## 1.0.0-dev.1.0

- Breaking: Removed deprecated `ReduxMachine` and related classes.
- Fixed: strong mode issues with Dart 2.

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
