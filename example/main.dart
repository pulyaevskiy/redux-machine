// Copyright (c) 2017, Anatoly Pulyaevskiy. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:redux_machine/redux_machine.dart';

/// Implementation of a simple coin-operated turnstile state machine
/// as described here:
/// https://en.wikipedia.org/wiki/Finite-state_machine#Example:_coin-operated_turnstile
void main() {
  // Create our machine and register reducers:
  final builder = new StoreBuilder<Turnstile>(
    initialState: new Turnstile(true, 0, 0),
  );
  builder
    ..bind(Actions.putCoin, putCoinReducer)
    ..bind(Actions.push, pushReducer);
  final store = builder.build();

  // Try triggering some actions
  store.dispatch(Actions.push());
  store.dispatch(Actions.putCoin());
  store.dispatch(Actions.push());
  store.dispatch(Actions.push());
  store.dispatch(Actions.push());
  store.dispatch(Actions.push());
  store.dispatch(Actions.putCoin());
  store.dispatch(Actions.putCoin());
  store.dispatch(Actions.push());
  store.dispatch(Actions.push());
  // .. etc.
  // Make sure to dispose the state store in the end:
  store.dispose();
}

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

abstract class Actions {
  /// Put coin to unlock turnstile
  static const putCoin = const VoidActionBuilder('putCoin');

  /// Push turnstile to pass through
  static const push = const VoidActionBuilder('push');
}

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
