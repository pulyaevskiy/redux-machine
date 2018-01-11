// Copyright (c) 2017, Anatoly Pulyaevskiy. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:redux_machine/redux_machine.dart';

/// Implementation of a simple coin-operated turnstile state machine
/// as described here:
/// https://en.wikipedia.org/wiki/Finite-state_machine#Example:_coin-operated_turnstile
void main() {
  ReduxMachine<TurnstileState> machine = new ReduxMachine<TurnstileState>();
  machine
    ..addReducer(Actions.putCoin, putCoinReducer)
    ..addReducer(Actions.push, pushReducer);

  machine.start(new TurnstileState(true, 0, 0));
  machine.trigger(Actions.push());
  machine.trigger(Actions.putCoin());
  machine.trigger(Actions.push());
  machine.trigger(Actions.push());
  machine.trigger(Actions.push());
  machine.trigger(Actions.push());
  machine.trigger(Actions.putCoin());
  machine.trigger(Actions.putCoin());
  machine.trigger(Actions.push());
  machine.trigger(Actions.push());
  machine.shutdown();
}

class TurnstileState {
  final bool isLocked;
  final int coinsCollected;
  final int visitorsPassed;

  TurnstileState(this.isLocked, this.coinsCollected, this.visitorsPassed);

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

class Actions {
  static const ActionBuilder<Null> putCoin =
      const ActionBuilder<Null>('putCoin');
  static const ActionBuilder<Null> push = const ActionBuilder<Null>('push');
}

TurnstileState putCoinReducer(
    TurnstileState state, Action action, MachineController controller) {
  int coinsCollected = state.coinsCollected + 1;
  print('Coins collected: $coinsCollected');
  return state.copyWith(isLocked: false, coinsCollected: coinsCollected);
}

TurnstileState pushReducer(
    TurnstileState state, Action action, MachineController controller) {
  int visitorsPassed = state.visitorsPassed;
  if (!state.isLocked) {
    visitorsPassed++;
    print('Visitors passed: ${visitorsPassed}');
  }
  return state.copyWith(isLocked: true, visitorsPassed: visitorsPassed);
}
