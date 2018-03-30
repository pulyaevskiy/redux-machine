// Copyright (c) 2018, Anatoly Pulyaevskiy. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:redux_machine/redux_machine.dart';
import 'package:test/test.dart';

void main() {
  group('StateMachine', () {
    Store<SimpleState> machine;

    setUp(() {
      final builder = new StoreBuilder<SimpleState>(
          initialState: new SimpleState(isLocked: true));
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

class SimpleState {
  final bool isLocked;
  final String data;

  SimpleState({this.isLocked, this.data = ''});

  SimpleState copyWith({bool isLocked, String data}) {
    return new SimpleState(
      isLocked: isLocked ?? this.isLocked,
      data: data ?? this.data,
    );
  }
}

class Actions {
  static const putCoin = const VoidActionBuilder('putCoin');
  static const push = const VoidActionBuilder('push');
  static const chain = const ActionBuilder<String>('chain');
  static const append = const ActionBuilder<String>('append');
  static const loop = const VoidActionBuilder('loop');
  static const chainError = const VoidActionBuilder('chainError');
  static const error = const VoidActionBuilder('error');
  static const dyn = const ActionBuilder<bool>('dyn');
}

SimpleState putCoinReducer(SimpleState state, Action<void> action) {
  return state.copyWith(isLocked: false);
}

SimpleState pushReducer(SimpleState state, Action<void> action) {
  return state.copyWith(isLocked: true);
}

SimpleState chainingReducer(SimpleState state, Action<String> action) {
  return action.next(
    Actions.append('-append'),
    state.copyWith(isLocked: false, data: action.payload),
  );
}

SimpleState appendReducer(SimpleState state, Action<String> action) {
  String data = state.data + action.payload;
  return state.copyWith(isLocked: false, data: data);
}

SimpleState loopReducer(SimpleState state, Action<void> action) {
  return action.next(Actions.loop(), state.copyWith());
}

SimpleState chainErrorReducer(SimpleState state, Action<void> action) {
  return action.next(Actions.error(), state.copyWith());
}

SimpleState errorReducer(SimpleState state, Action<void> action) {
  throw new StateError('Error');
}

SimpleState dynamicReducer(SimpleState state, Action<bool> action) {
  if (action.payload) {
    return action.next(Actions.putCoin(), state.copyWith());
  } else {
    return action.next(Actions.chain('dynamicChained'), state.copyWith());
  }
}
