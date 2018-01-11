// Copyright (c) 2017, Anatoly Pulyaevskiy. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:redux_machine/redux_machine.dart';
import 'package:test/test.dart';

void main() {
  group('ReduxMachine', () {
    ReduxMachine<SimpleState> machine;

    setUp(() {
      machine = new ReduxMachine<SimpleState>({
        Actions.putCoin.name: putCoinReducer,
        Actions.push.name: pushReducer,
        Actions.chain.name: chainingReducer,
        Actions.append.name: appendReducer,
      });
    });

    test('isStarted', () {
      expect(machine.isStarted, isFalse);
      machine.start(new SimpleState(true));
      expect(machine.isStarted, isTrue);
    });

    test('trigger if not started', () {
      expect(() {
        machine.trigger(Actions.push());
      }, throwsA(new isInstanceOf<AssertionError>()));
    });

    test('trigger', () {
      machine.start(new SimpleState(true));
      expect(machine.state.isLocked, isTrue);
      machine.trigger(Actions.putCoin());
      expect(machine.state.isLocked, isFalse);
      machine.trigger(Actions.push());
      expect(machine.state.isLocked, isTrue);
    });

    test('trigger chained', () {
      machine.start(new SimpleState(true));
      machine.trigger(Actions.chain('chain'));
      expect(machine.state.data, 'chain-append');
    });
  });
}

class SimpleState {
  final bool isLocked;
  final String data;

  SimpleState(this.isLocked, [this.data = '']);

  SimpleState copyWith({bool isLocked, String data}) {
    return new SimpleState(isLocked ?? this.isLocked, data ?? this.data);
  }
}

class Actions {
  static const ActionBuilder<Null> putCoin =
      const ActionBuilder<Null>('putCoin');
  static const ActionBuilder<Null> push = const ActionBuilder<Null>('push');
  static const ActionBuilder<String> chain =
      const ActionBuilder<String>('chain');
  static const ActionBuilder<String> append =
      const ActionBuilder<String>('append');
}

SimpleState putCoinReducer(
    SimpleState state, Action<Null> action, MachineController controller) {
  return state.copyWith(isLocked: false);
}

SimpleState pushReducer(
    SimpleState state, Action<Null> action, MachineController controller) {
  return state.copyWith(isLocked: true);
}

SimpleState chainingReducer(
    SimpleState state, Action<String> action, MachineController controller) {
  controller.become(Actions.append('-append'));
  return state.copyWith(isLocked: false, data: action.payload);
}

SimpleState appendReducer(
    SimpleState state, Action<String> action, MachineController controller) {
  String data = state.data + action.payload;
  return state.copyWith(isLocked: false, data: data);
}
