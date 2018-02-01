# redux_machine

[![Build Status](https://travis-ci.org/pulyaevskiy/redux-machine.svg?branch=master)](https://travis-ci.org/pulyaevskiy/redux-machine) [![Pub](https://img.shields.io/pub/v/redux_machine.svg)](https://pub.dartlang.org/packages/redux_machine)

Originally started to provide implementation of a State Machine using
Redux design pattern, this library now includes its own Redux Store
which can be used without the state machine part.

Important difference from other Redux implementations is in how
side-effects are handled. ReduxMachine's opinion on this is simple -
side-effects are not allowed in the action dispatch flow
(dispatch-reduce-updateState).

Practical implications of this rule are:

- reducers must be pure functions (no asynchronous logic)
- no middleware (in the traditional form), middleware-like functionality
  is still allowed, as long as there is no side-effects.

Why? One of the main benefits of Redux pattern is  how it reduces
(no pun intended) cognitive load when modeling larger applications.
Side-effects effectively remove this benefit.

ReduxMachine tries to avoid traditional middleware approach and
keep side-effects out of the main action-reducer-state flow.
It is not a new work and some inspiration has been taken from a few
different online resources like [this][goshakkk] and [this][ward].

[goshakkk]: https://goshakkk.name/redux-side-effect-approaches/
[ward]: https://medium.com/javascript-and-opinions/redux-side-effects-and-you-66f2e0842fc3

Provided APIs for `StateMachine` and `Store` classes are also designed
to allow better static type analysis so you could catch errors earlier.

## StateMachine Usage

> TL;DR see full source code of this example in the `example/` folder.

Redux requires three things: state, actions and reducers.

We start by defining our state object. Here is an example of a coin-operated
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
  static const ActionBuilder<Null> putCoin =
      const ActionBuilder<Null>('putCoin');
  /// Push turnstile to pass through
  static const ActionBuilder<Null> push = const ActionBuilder<Null>('push');
}
```

And reducers:

```dart
Turnstile putCoinReducer(
    Turnstile state, Action<Null> action, ActionDispatcher dispatcher) {
  int coinsCollected = state.coinsCollected + 1;
  print('Coins collected: $coinsCollected');
  return state.copyWith(isLocked: false, coinsCollected: coinsCollected);
}

Turnstile pushReducer(
    Turnstile state, Action<Null> action, ActionDispatcher dispatcher) {
  int visitorsPassed = state.visitorsPassed;
  if (!state.isLocked) {
    visitorsPassed++;
    print('Visitors passed: ${visitorsPassed}');
  }
  return state.copyWith(isLocked: true, visitorsPassed: visitorsPassed);
}
```

Now get it all together:

```dart
void main() {
  // Create our machine and register reducers:
  final builder = new StateMachineBuilder<Turnstile>(
    initialState: new Turnstile(true, 0, 0));
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

### Chaining actions

Sometimes it is useful to trigger another action from inside current reducer.
It is possible via `ActionDispatcher` argument passed to each reducer function.
Simply invoke it `dispatcher(yourNextAction(payload));` before returning
updated state, e.g.:

```dart
State exampleReducer(
    State state, Action<Null> action, ActionDispatcher dispatcher) {
  // do work here
  // ...

  // State machine will call reducer for `otherAction` with the state object 
  // returned from this reducer.
  dispatcher(Actions.otherAction());

  return state.copyWith(exampleField: 'value');
}
```

## Middleware example 1: logging

`ReduxMachine` and `Store` classes expose `events` stream which
contains all dispatched actions and their results. So logging middleware
becomes a simple stream subscription. Printing to stdout:

```dart
final Store<MyState> store = getStore();
// Print all events to stdout:
store.events.listen(print);
```

## Middleware example 2: error reporting

Since action dispatch flow is side-effect free handling exceptions in
reducers is straightforward. To track unhandled errors you can set the
`onError` handler on `StoreBuilder` (and `StateMachineBuilder`):

```dart
final StoreBuilder<MyState> builder = new StoreBuilder(
  onError: errorHandler);

// Example error handler
void errorHandler(MyState state, Action action, error) {
  // Avoid having async logic in here.
  errorsSync.add(error);
  // Throw the error in the end.
  throw error;
}
```

The `onError` handler is executed as part of the action dispatch
flow therefore it must be pure. Instead of doing any async logic
inside the handler consider leveraging an `EventSink` to collect
errors and publish asynchronously.

If `onError` is omitted it defaults to a handler which simply throws
all errors.

Actions which resulted in an error are not published to the `events`
stream.

## Middleware example 3: making HTTP request

```dart
final Store<MyState> store = getStore();
// Note that async is allowed in event listeners
store.eventsWhere(Actions.fetchUser).listen((event) async {
  try {
    int userId = event.newState.fetchingUserId;
    final user = await fetchUser(userId);
    store.dispatch(Actions.userFetched(user));
  } catch (error) {
    store.dispatch(Actions.userFetchFailed(error));
  }
});

// Assuming there is a reducer which simply sets
// store.state.fetchingUserId = action.payload; // 123 in this case
store.dispatch(Actions.fetchUser(123));
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[turnstile]: https://en.wikipedia.org/wiki/Finite-state_machine#Example:_coin-operated_turnstile
[tracker]: https://github.com/pulyaevskiy/redux-machine/issues
