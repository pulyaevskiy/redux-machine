[![Build Status](https://travis-ci.org/pulyaevskiy/redux-machine.svg?branch=master)](https://travis-ci.org/pulyaevskiy/redux-machine) [![Pub](https://img.shields.io/pub/v/redux_machine.svg)](https://pub.dartlang.org/packages/redux_machine) [![Pub latest](https://img.shields.io/badge/pub%40latest-1.0.0--dev-orange.svg)](https://pub.dartlang.org/packages/redux_machine/versions/1.0.0-dev.1.0)

Originally started to provide implementation of a State Machine using
Redux design pattern, this library now includes its own Redux Store
which can be used without the state machine part.

The provided `Store` class implements usual Redux state store and `StateMachine`
class adds some extra functionality mostly to allow chained actions.

Action dispatch flow of both classes is very simple:

1. User dispatches an action
2. Store executes corresponding reducer function.
3. Store publishes an event with results (includes oldState and newState).

There is no middleware or anything else special. Reducers are pure functions,
and dispatching an action is always synchronous.

Main consequence of this design is that there is no place for middleware layer.
There are other mechanisms provided by redux_machine that replace middleware.

## Usage

> TL;DR see full source code of this example in the `example/` folder.

Redux requires three things: state, actions and reducers.

We start by defining our state object. Below is an example of a coin-operated
turnstile ([from Wikipedia][turnstile]):

```dart
class Turnstile<T> extends MachineState<T> {
  final bool isLocked;
  final int coinsCollected;
  final int visitorsPassed;

  Turnstile(this.isLocked, this.coinsCollected, this.visitorsPassed,
      Action<T> nextAction)
      : super(nextAction);

  /// Convenience method to use in reducers.
  Turnstile<R> copyWith<R>({
    bool isLocked,
    int coinsCollected,
    int visitorsPassed,
    Action<R> nextAction,
  }) {
    return new Turnstile(
      isLocked ?? this.isLocked,
      coinsCollected ?? this.coinsCollected,
      visitorsPassed ?? this.visitorsPassed,
      nextAction,
    );
  }
}
```

Next, actions:

```dart
abstract class Actions {
  /// Put coin to unlock turnstile
  static const putCoin = const ActionBuilder<void>('putCoin');

  /// Push turnstile to pass through
  static const push = const ActionBuilder<void>('push');
}
```

And reducers:

```dart
Turnstile putCoinReducer(Turnstile state, Action<void> action) {
  int coinsCollected = state.coinsCollected + 1;
  print('Coins collected: $coinsCollected');
  return state.copyWith(isLocked: false, coinsCollected: coinsCollected);
}

Turnstile pushReducer(Turnstile state, Action<void> action) {
  int visitorsPassed = state.visitorsPassed;
  if (!state.isLocked) {
    visitorsPassed++;
    print('Visitors passed: ${visitorsPassed}');
  }
  return state.copyWith(isLocked: true, visitorsPassed: visitorsPassed);
}
```

Combining everything together:

```dart
void main() {
  // Create our machine and register reducers using provided builder class:
  final builder = new StateMachineBuilder<Turnstile>(
    initialState: new Turnstile(true, 0, 0, null));
  builder
    ..bind(Actions.putCoin, putCoinReducer)
    ..bind(Actions.push, pushReducer);
  final machine = builder.build();

  // Try triggering some actions
  machine.dispatch(Actions.push());
  machine.dispatch(Actions.putCoin());
  // .. etc.
  // Make sure to dispose the machine in the end:
  machine.dispose();
}
```

### Chaining actions with StateMachine

Sometimes it is useful to trigger another action from inside current reducer.
It is possible via `nextAction` property of `MachineState` base class. This
class must be extended by your state class as shown above in the Turnstile
example. Scheduling an action is as simple as returning a state object
with the desired action, e.g.:

```dart
State exampleReducer( State state, Action<void> action) {
  // do work here
  // ...

  // State machine will call reducer for `otherAction` with the state object
  // returned from this reducer.
  return state.copyWith(
    exampleField: 'value',
    nextAction: Actions.otherAction()
  );
}
```

## Middleware example 1: logging

`StateMachine` and `Store` classes expose `events` stream which
contains all dispatched actions and their results. So logging middleware
becomes a simple stream subscription. Below is simplistic printing to stdout
of all events:

```dart
final Store<MyState> store = getStore();
// Print all events to stdout:
store.events.listen(print);
```

## Middleware example 2: error reporting

Any unhandled errors in reducers are forwarded to the `errors` stream if there
is an active listener on it. If there is no active listener all errors are
simply rethrown during dispatch.

> Note that `Store.errors` stream contains instances of `StoreError` which provide
> details about the failed action and current state. In case there is no
> listener on this stream the unhandled error from reducer is rethrown as-is
> (not wrapped with `StoreError`) to preserve original stack trace.

To log all unhandled errors listen on the "errors" stream.

```dart
final Store<MyState> store = getStore();
// Print all events to stdout:
store.errors.listen(null, onError: errorHandler, cancelOnError: false);

// Example error handler
void errorHandler(error, stackTrace) {
  // Log error somewhere...
}
```

Actions which resulted in an error do not publish a `StoreEvent` to the `events`
stream.

## Middleware example 3: making HTTP request

In below example we use `Store.eventsFor` stream returns a stream of events
produced by the same action type (in this case all "fetchUser" events).

```dart
final Store<MyState> store = getStore();
// Note that async is allowed in event listeners.
store.eventsFor(Actions.fetchUser).listen((Action<String> event) async {
  try {
    // assuming action payload is the ID of a user to fetch.
    String userId = event.action.payload;
    final user = await fetchUserFromHttpApi(userId);
    store.dispatch(Actions.userFetched(user));
  } catch (error) {
    store.dispatch(Actions.userFetchFailed(error));
  }
});

store.dispatch(Actions.fetchUser('user-id-here'));
```

## Async actions (experimental)

`AsyncAction` is like regular Redux `Action` except it also carries a `Future`.
In many cases it can be a simpler alternative to traditional trio of actions
`doFoo`, `doFooSuccess` and `doFooFailed`.

Common use case for async actions is when no explicit UI interaction is
expected with the user after the action is done. For intance, deleting
content or swiping list items left or right.

### Using async actions

Async actions assume there are side-effects involved so they are normally
handled by an event stream listener where side-effects are allowed:

```dart
abstract class Actions {
  /// Action payload is an integer ID of the note to delete.
  static const deleteNote = const AsyncActionBuilder<int>('deleteNote');
}

// Subscribing to deleteNote events.
Store buildStore() {
  final builder = new StoreBuilder<AppState>();
  // ...bind reducers
  final store = builder.build();
  store.eventsFor(Actions.deleteNote).listen(_deleteNote);
}

/// Listener for deleteNote events
_deleteNote(StoreEvent<AppState, int> event) async {
  AsyncAction<int> action = event.action;
  int noteId = action.payload;
  try {
    var result = httpClient.send('DELETE', '/notes/$noteId');
    // Delete successful, mark the action as done
    action.complete();
  } catch (error) {
    action.completeError(error);
  }
}

// Somewhere on the client side where the action is dispatched
deleteNoteButtonPressed(int noteId) async {
  final action = Actions.deleteNote(noteId);
  store.dispatch(action);
  // refresh UI to show loading state, pseudo-code
  setState(isLoading: true);
  try {
    await action.done;
    setState(isLoading: false); // refresh UI, delete successful
  } catch (error) {
    // failed to delete, show the error.
    setState(errorMessage: error.toString());
  }
}
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[turnstile]: https://en.wikipedia.org/wiki/Finite-state_machine#Example:_coin-operated_turnstile
[tracker]: https://github.com/pulyaevskiy/redux-machine/issues
