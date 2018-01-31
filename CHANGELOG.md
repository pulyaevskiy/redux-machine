# Changelog

## 0.1.1

- Added type argument to `StoreEvent` for the action payload type for
  better static analysis.

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
