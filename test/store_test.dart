// Copyright (c) 2018, Anatoly Pulyaevskiy. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:redux_machine/redux_machine.dart';
import 'package:test/test.dart';

void main() {
  group('Store', () {
    Store<Car> store;

    setUp(() {
      final builder = new StoreBuilder<Car>(
          initialState: new Car(false, HeadlampsMode.off));
      builder
        ..bind(Actions.turnEngineOn, turnEngineOn)
        ..bind(Actions.switchHeadlamps, switchHeadlampsTo)
        ..bind(Actions.error, errorReducer)
        ..bind(Actions.asyncDo, asyncDoReducer);
      store = builder.build();
    });

    test('dispatch', () {
      store.dispatch(Actions.turnEngineOn(true));
      expect(store.state.isEngineOn, true);
    });

    test('events', () {
      var events = store.events.toList();
      store.dispatch(Actions.turnEngineOn(true));
      store.dispatch(Actions.notBound());
      store.dispose();
      expect(events, completion(hasLength(2)));
    });

    test('eventsFor', () {
      var events = store.eventsFor(Actions.notBound).toList();
      store.dispatch(Actions.turnEngineOn(true));
      store.dispatch(Actions.notBound());
      store.dispose();
      expect(events, completion(hasLength(1)));
    });

    test('changes', () {
      var events = store.changes.toList();
      store.dispatch(Actions.turnEngineOn(true));
      store.dispatch(Actions.notBound());
      store.dispatch(Actions.switchHeadlamps(HeadlampsMode.on));
      store.dispose();
      expect(events, completion(hasLength(2)));
    });

    test('changesFor', () {
      var events = store.changesFor((car) => car.headlamps).toList();
      store.dispatch(Actions.turnEngineOn(true));
      store.dispatch(Actions.switchHeadlamps(HeadlampsMode.on));
      store.dispatch(Actions.switchHeadlamps(HeadlampsMode.on));
      store.dispatch(Actions.switchHeadlamps(HeadlampsMode.highBeams));
      store.dispatch(Actions.switchHeadlamps(HeadlampsMode.off));
      store.dispose();
      expect(events, completion(hasLength(4)));
    });

    test('stack trace with no listener', () async {
      StackTrace trace;
      try {
        store.dispatch(Actions.error());
      } catch (error, stackTrace) {
        trace = stackTrace;
      }
      expect(trace.toString(), contains('errorReducer'));
    });

    test('stack trace with a listener', () async {
      StackTrace trace;
      try {
        var result = store.errors.toList();
        store.dispatch(Actions.error());
        store.dispose();
        await result;
      } catch (error, stackTrace) {
        trace = stackTrace;
      }
      expect(trace.toString(), contains('errorReducer'));
    });

    test('dispatch async action', () async {
      var events = store.eventsFor(Actions.asyncDo).toList();
      store.dispatch(Actions.asyncDo());
      store.dispose();
      var list = await events;
      expect(list, hasLength(1));
    });
  });
}

class Actions {
  static const turnEngineOn = const ActionBuilder<bool>('turnEngineOn');
  static const switchHeadlamps =
      const ActionBuilder<HeadlampsMode>('switchHeadlamps');
  static const error = const VoidActionBuilder('error');
  static const notBound = const VoidActionBuilder('notBound');
  static const asyncDo = const AsyncVoidActionBuilder('asyncDo');
}

enum HeadlampsMode { off, on, highBeams }

class Car {
  final bool isEngineOn;
  final HeadlampsMode headlamps;

  Car(this.isEngineOn, this.headlamps);

  @override
  String toString() => '$Car{isEngineOn: $isEngineOn, headlamps: $headlamps}';
}

Car turnEngineOn(Car state, Action<bool> action) {
  return new Car(action.payload, state.headlamps);
}

Car switchHeadlampsTo(Car state, Action<HeadlampsMode> action) {
  return new Car(state.isEngineOn, action.payload);
}

Car errorReducer(Car state, Action<void> action) {
  throw new StateError('Something bad happened');
}

Car asyncDoReducer(Car state, Action<void> action) {
  return new Car(true, HeadlampsMode.off);
}
