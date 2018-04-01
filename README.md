[![Build Status](https://travis-ci.org/pulyaevskiy/redux-machine.svg?branch=master)](https://travis-ci.org/pulyaevskiy/redux-machine) [![Pub](https://img.shields.io/pub/v/redux_machine.svg)](https://pub.dartlang.org/packages/redux_machine) [![Pub latest](https://img.shields.io/badge/pub%40latest-1.0.0--dev-orange.svg)](https://pub.dartlang.org/packages/redux_machine/versions/1.0.0-dev.1.0)

Originally started to provide implementation of a State Machine using
Redux design pattern, this library now includes a Redux Store
which can be used as a regular state store or a state machine.

This library implements simplified action dispatch flow:

1. User dispatches an action
2. Store executes corresponding reducer function, synchronously.
3. Store publishes a `StoreEvent` as a result into `events` stream.

There is no middleware or anything else special. Reducers are pure functions,
and dispatching an action is always synchronous.

Main consequence of this design is that there is no place for middleware layer,
however there are other mechanisms provided by redux_machine that cover
middleware use cases.

## Usage

> TL;DR see full source code of this example in the `example/` folder.

Redux requires three things: state, actions and reducers.

We start by defining our state object. Below is an example of a coin-operated
turnstile ([from Wikipedia][turnstile]):

```dart
class Turnstile {
  final bool isLocked;
  final int coinsCollected;
  final int visitorsPassed;

  Turnstile(this.isLocked, this.coinsCollected, this.visitorsPassed);

  /// Convenience method to use in reducers.
  Turnstile copyWith({
    bool isLocked,
    int coinsCollected,
    int visitorsPassed,
  }) {
    return new Turnstile(
      isLocked ?? this.isLocked,
      coinsCollected ?? this.coinsCollected,
      visitorsPassed ?? this.visitorsPassed,
    );
  }
}
```

Next, actions:

```dart
abstract class Actions {
  /// Put coin to unlock turnstile
  static const putCoin = const VoidActionBuilder('putCoin');

  /// Push turnstile to pass through
  static const push = const VoidActionBuilder('push');
}
```

There are 4 action builder classes provided for most common use cases. Above
example shows usage of `VoidActionBuilder` which creates `Action`s with no
(`void`) payload. Here are examples of using all 4 builders:

```dart
abstract class Actions {
  /// The same example as above.
  static const putCoin = const VoidActionBuilder('putCoin');

  /// Regular action builder with [String] payload. Payload is required.
  static const getUser = const ActionBuilder<String>('getUser');

  /// The same as [VoidActionBuilder] but creates [AsyncAction] with no payload.
  /// Read more on async actions below in this document.
  static const clearCache = const AsyncVoidActionBuilder('clearCache');

  /// Similarly creates [AsyncAction] with required payload of type [String].
  static const deleteUser = const AsyncActionBuilder<String>('deleteUser');
}

/// Using builders
Future<void> main() async {
  final Store<MyState> store = getStore();
  /// All builders implement [call] method and can be invoked as a regular
  /// function. [call] method of `void` builders has zero arguments.
  store.dispatch(Actions.putCoin());

  /// `Async*` builders create [AsyncAction]s which allow dispatching side
  /// to know when action is completed via [AsyncAction.done] Future.
  final clearCache = Actions.clearCache();
  store.dispatch(clearCache);
  await clearCache.done;

  /// [ActionBuilder] and [AsyncActionBuilder] implement `call` method with
  /// single argument - payload for the created action:
  store.dispatch(Actions.getUser('user-id'));
  /// Or:
  final deleteUser = Actions.deleteUser('user-id');
  store.dispatch(deleteUser);
  await deleteUser.done;
}
```

Next step, reducers:

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
  // Create Redux store and register reducers using provided builder class:
  final builder = new StoreBuilder<Turnstile>(
    initialState: new Turnstile(true, 0, 0),
  );
  builder
    ..bind(Actions.putCoin, putCoinReducer)
    ..bind(Actions.push, pushReducer);
  final store = builder.build();

  // Try triggering some actions
  machine.dispatch(Actions.push());
  machine.dispatch(Actions.putCoin());
  // .. etc.
  // Make sure to dispose the machine in the end:
  machine.dispose();
}
```

### Chaining actions

Sometimes it is useful to trigger another action from inside current reducer.
It is possible via `Action.next()` method:

```dart
State exampleReducer(State state, Action<void> action) {
  // do work here
  // ...
  final newState = state.copyWith(exampleField: 'value');
  // State store will dispatch `otherAction` and pass `newState` as an input
  // state argument.
  return action.next(newState, Actions.otherAction());
}
```

> Note that `Action.next` does not perform actual dispatch so calling it multiple
> times within a reducer function has no chaining effect. Only action passed
> to the last invocation of `Action.next` will be dispatched by the state store.

## Middleware example 1: logging

`Store` class exposes `events` stream which
contains all dispatched actions and their results. Logging middleware
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

void errorHandler(error, stackTrace) {
  print(error);
  print(stackTrace);
}
```

Actions which resulted in an error do not publish a `StoreEvent` to the `events`
stream.

## Middleware example 3: making HTTP request

In below example we use `Store.eventsFor` stream which returns a stream of
events produced by the same action type (in this case all "fetchUser" events).

```dart
final Store<MyState> store = getStore();
// Note that async is allowed in event listeners.
store.eventsFor(Actions.fetchUser).listen((StoreEvent<MyState, String> event) async {
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
In many cases it can be a simpler alternative to traditional trio of
`doFoo`, `doFooSuccess` and `doFooFailed` actions.

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
    var result = await httpClient.send('DELETE', '/notes/$noteId');
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
