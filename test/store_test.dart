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
    Store<SimpleState> store;

    setUp(() {
      final builder =
          new StoreBuilder<SimpleState>(initialState: new SimpleState(false));
      builder
        ..bind(Actions.empty, emptyReducer)
        ..bind(Actions.error, errorReducer);
      store = builder.build();
    });

    test('dispatch', () {
      store.dispatch(Actions.empty(true));
      expect(store.state.isEmpty, true);
    });

    test('events', () {
      var events = store.events.toList();
      store.dispatch(Actions.empty(true));
      store.dispatch(Actions.notBound());
      store.dispose();
      expect(events, completion(hasLength(2)));
    });

    test('eventsWhere', () {
      var events = store.eventsWhere(Actions.notBound).toList();
      store.dispatch(Actions.empty(true));
      store.dispatch(Actions.notBound());
      store.dispose();
      expect(events, completion(hasLength(1)));
    });

    test('changes', () {
      var events = store.changes.toList();
      store.dispatch(Actions.empty(true));
      store.dispatch(Actions.notBound());
      store.dispose();
      expect(events, completion(hasLength(1)));
    });

    test('errors', () {
      var events = store.events.toList();
      store.dispatch(Actions.error());
      expect(events, throwsStoreError);
    });
  });
}

class Actions {
  static const ActionBuilder<bool> empty = const ActionBuilder<bool>('empty');
  static const ActionBuilder<Null> error = const ActionBuilder<Null>('error');
  static const ActionBuilder<Null> notBound =
      const ActionBuilder<Null>('notBound');
}

class SimpleState {
  final bool isEmpty;

  SimpleState(this.isEmpty);
}

SimpleState emptyReducer(SimpleState state, Action<bool> action) {
  return new SimpleState(action.payload);
}

SimpleState errorReducer(SimpleState state, Action<bool> action) {
  throw new StateError('Something bad happened');
}
