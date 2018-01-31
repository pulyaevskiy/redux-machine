// Copyright (c) 2017, Anatoly Pulyaevskiy. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:redux_machine/redux_machine.dart';
import 'package:test/test.dart';

void main() {
  group('StateMachine', () {
    StateMachine<SimpleState> machine;

    setUp(() {
      final builder = new StateMachineBuilder<SimpleState>(
          initialState: new SimpleState(true));
      builder
        ..bind(Actions.putCoin, putCoinReducer)
        ..bind(Actions.push, pushReducer)
        ..bind(Actions.chain, chainingReducer)
        ..bind(Actions.append, appendReducer)
        ..bind(Actions.loop, loopReducer);
      machine = builder.build();
    });

    tearDown(() {
      machine.dispose();
    });

    test('initialState', () {
      expect(machine.state.isLocked, isTrue);
    });

    test('trigger', () {
      expect(machine.state.isLocked, isTrue);
      machine.dispatch(Actions.putCoin());
      expect(machine.state.isLocked, isFalse);
      machine.dispatch(Actions.push());
      expect(machine.state.isLocked, isTrue);
    });

    test('trigger chained', () {
      machine.dispatch(Actions.chain('chain'));
      expect(machine.state.data, 'chain-append');
    });

    test('trigger infinite loop', () {
      expect(() {
        machine.dispatch(Actions.loop());
      }, throwsStateError);
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
  static const ActionBuilder<Null> loop = const ActionBuilder<Null>('loop');
}

SimpleState putCoinReducer(
    SimpleState state, Action<Null> action, ActionDispatcher dispatchNext) {
  return state.copyWith(isLocked: false);
}

SimpleState pushReducer(
    SimpleState state, Action<Null> action, ActionDispatcher dispatchNext) {
  return state.copyWith(isLocked: true);
}

SimpleState chainingReducer(
    SimpleState state, Action<String> action, ActionDispatcher dispatchNext) {
  dispatchNext(Actions.append('-append'));
  return state.copyWith(isLocked: false, data: action.payload);
}

SimpleState appendReducer(
    SimpleState state, Action<String> action, ActionDispatcher dispatchNext) {
  String data = state.data + action.payload;
  return state.copyWith(isLocked: false, data: data);
}

SimpleState loopReducer(
    SimpleState state, Action<String> action, ActionDispatcher dispatchNext) {
  dispatchNext(Actions.loop());
  return state.copyWith();
}
