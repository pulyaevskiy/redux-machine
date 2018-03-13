// Copyright (c) 2018, Anatoly Pulyaevskiy. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:redux_machine/redux_machine.dart';
import 'package:test/test.dart';

void main() {
  group('StateMachine', () {
    StateMachine<SimpleState> machine;

    setUp(() {
      final builder = new StateMachineBuilder<SimpleState>(
          initialState: new SimpleState<Null>(isLocked: true));
      builder
        ..bind(Actions.putCoin, putCoinReducer)
        ..bind(Actions.push, pushReducer)
        ..bind(Actions.chain, chainingReducer)
        ..bind(Actions.append, appendReducer)
        ..bind(Actions.loop, loopReducer)
        ..bind(Actions.chainError, chainErrorReducer)
        ..bind(Actions.error, errorReducer)
        ..bind(Actions.dyn, dynamicReducer);
      machine = builder.build();
    });

    tearDown(() {
      machine.dispose();
    });

    test('initialState', () {
      expect(machine.state.isLocked, isTrue);
    });

    test('dispatch', () {
      expect(machine.state.isLocked, isTrue);
      machine.dispatch(Actions.putCoin());
      expect(machine.state.isLocked, isFalse);
      machine.dispatch(Actions.push());
      expect(machine.state.isLocked, isTrue);
    });

    test('dispatch chained', () {
      machine.dispatch(Actions.chain('chain'));
      expect(machine.state.data, 'chain-append');
    });

    test('dispatch dynamic', () async {
      var result = machine.eventsFor(Actions.chain).toList();
      machine.dispatch(Actions.dyn(false));
      machine.dispose();
      var events = await result;
      expect(events, hasLength(1));
      expect(events.first.action.payload, 'dynamicChained');
      expect(machine.state.data, 'dynamicChained-append');
    });

    test('dispatch infinite loop', () {
      expect(() {
        machine.dispatch(Actions.loop());
      }, throwsStateError);
    });

    test('stack trace on dispatch with chained error and a listener', () async {
      StackTrace trace;
      try {
        var result = machine.events.toList();
        machine.dispatch(Actions.chainError());
        machine.dispose();
        await result;
      } catch (error, stackTrace) {
        trace = stackTrace;
      }
      expect(trace.toString(), contains('errorReducer'));
    });
  });
}

class SimpleState<T> extends MachineState<T> {
  final bool isLocked;
  final String data;

  SimpleState({
    this.isLocked,
    this.data = '',
    Action<T> nextAction,
  }) : super(nextAction);

  SimpleState<R> copyWith<R>(
      {bool isLocked, String data, Action<R> nextAction}) {
    return new SimpleState<R>(
      isLocked: isLocked ?? this.isLocked,
      data: data ?? this.data,
      nextAction: nextAction,
    );
  }
}

class Actions {
  static const putCoin = const ActionBuilder<void>('putCoin');
  static const push = const ActionBuilder<void>('push');
  static const chain = const ActionBuilder<String>('chain');
  static const append = const ActionBuilder<String>('append');
  static const loop = const ActionBuilder<void>('loop');
  static const chainError = const ActionBuilder<void>('chainError');
  static const error = const ActionBuilder<void>('error');
  static const dyn = const ActionBuilder<bool>('dyn');
}

SimpleState putCoinReducer(SimpleState state, Action<void> action) {
  return state.copyWith(isLocked: false);
}

SimpleState pushReducer(SimpleState state, Action<void> action) {
  return state.copyWith(isLocked: true);
}

SimpleState chainingReducer(SimpleState state, Action<String> action) {
  return state.copyWith(
      isLocked: false,
      data: action.payload,
      nextAction: Actions.append('-append'));
}

SimpleState appendReducer(SimpleState state, Action<String> action) {
  String data = state.data + action.payload;
  return state.copyWith(isLocked: false, data: data);
}

SimpleState loopReducer(SimpleState state, Action<void> action) {
  return state.copyWith(nextAction: Actions.loop());
}

SimpleState chainErrorReducer(SimpleState state, Action<void> action) {
  return state.copyWith(nextAction: Actions.error());
}

SimpleState errorReducer(SimpleState state, Action<void> action) {
  throw new StateError('Error');
}

SimpleState dynamicReducer(SimpleState state, Action<bool> action) {
  if (action.payload) {
    return state.copyWith(nextAction: Actions.putCoin());
  } else {
    return state.copyWith(nextAction: Actions.chain('dynamicChained'));
  }
}
