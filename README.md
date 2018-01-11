# redux_machine

Writing state machines is hard, but not with this library.

Inspired by some work that can be found on the Internet, this is a
small library which allows implementing state machines powered by Redux flow.

## Usage

Redux requires three things: state, actions and reducers.

We start by defining our state object. Here is an example of a coin-operated
turnstile ([from Wikipedia][turnstile]):

```dart
class TurnstileState {
  final bool isLocked;
  final int coinsCollected;
  final int visitorsPassed;

  TurnstileState(this.isLocked, this.coinsCollected, this.visitorsPassed);

  /// Convenience method to use in reducers.
  TurnstileState copyWith({
    bool isLocked,
    int coinsCollected,
    int visitorsPassed,
  }) {
    return new TurnstileState(
      isLocked ?? this.isLocked,
      coinsCollected ?? this.coinsCollected,
      visitorsPassed ?? this.visitorsPassed,
    );
  }
}
```

Next, actions:

```dart
class Actions {
  /// Put coin to unlock turnstile
  static const ActionBuilder<Null> putCoin =
      const ActionBuilder<Null>('putCoin');
  /// Push turnstile to pass through
  static const ActionBuilder<Null> push = const ActionBuilder<Null>('push');
}
```

And reducers:

```dart
TurnstileState putCoinReducer(
    TurnstileState state, Action<Null> action, MachineController controller) {
  int coinsCollected = state.coinsCollected + 1;
  print('Coins collected: $coinsCollected');
  return state.copyWith(isLocked: false, coinsCollected: coinsCollected);
}

TurnstileState pushReducer(
    TurnstileState state, Action<Null> action, MachineController controller) {
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
  ReduxMachine<TurnstileState> machine = new ReduxMachine<TurnstileState>({
    Actions.putCoin.name: putCoinReducer,
    Actions.push.name: pushReducer,
  });

  // Start the machine with initial state.
  machine.start(new TurnstileState(true, 0, 0));
  // Try triggering some actions
  machine.trigger(Actions.push());
  machine.trigger(Actions.putCoin());
  // .. etc.
}
```

### Chaining actions

Sometimes it is useful to trigger another action from inside current reducer.
It is possible via `MachineController` argument passed to each reducer function.
Simply call `controller.become(yourNextAction(payload));` before returning
updated state, e.g.:

```dart
State exampleReducer(
    State state, Action<Null> action, MachineController controller) {
  // do work here
  // ...

  // State machine will call reducer for `otherAction` with the state object 
  // returned from this reducer.
  controller.become(Actions.otherAction());

  return state.copyWith(exampleField: 'value');
}
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[turnstile]: https://en.wikipedia.org/wiki/Finite-state_machine#Example:_coin-operated_turnstile
[tracker]: https://github.com/pulyaevskiy/redux-machine/issues
