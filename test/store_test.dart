// Copyright (c) 2017, Anatoly Pulyaevskiy. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:redux_machine/redux_machine.dart';
import 'package:test/test.dart';

const Matcher isStoreError = const _StoreError();

class _StoreError extends TypeMatcher {
  const _StoreError() : super("StoreError");
  bool matches(item, Map matchState) => item is StoreError;
}

final Matcher throwsStoreError = throwsA(const _StoreError());

void main() {
  group('Store', () {
    Store<Car> store;

    setUp(() {
      final builder = new StoreBuilder<Car>(
          initialState: new Car(false, HeadlampsMode.off));
      builder
        ..bind(Actions.turnEngineOn, turnEngineOn)
        ..bind(Actions.switchHeadlamps, switchHeadlampsTo)
        ..bind(Actions.error, errorReducer);
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

    test('eventsWhere', () {
      var events = store.eventsWhere(Actions.notBound).toList();
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

    test('errors', () {
      var events = store.events.toList();
      store.dispatch(Actions.error());
      expect(events, throwsStoreError);
    });
  });
}

class Actions {
  static const ActionBuilder<bool> turnEngineOn =
      const ActionBuilder<bool>('turnEngineOn');
  static const ActionBuilder<HeadlampsMode> switchHeadlamps =
      const ActionBuilder<HeadlampsMode>('switchHeadlamps');
  static const ActionBuilder<Null> error = const ActionBuilder<Null>('error');
  static const ActionBuilder<Null> notBound =
      const ActionBuilder<Null>('notBound');
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

Car errorReducer(Car state, Action<bool> action) {
  throw new StateError('Something bad happened');
}
