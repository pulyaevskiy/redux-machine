// Copyright (c) 2018, Anatoly Pulyaevskiy. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';

/// Redux action for state [Store].
///
/// Actions trigger state transitions and are handled by a corresponding reducer
/// function.
///
/// While you can create an action by instantiating it directly it is recommended
/// to use [ActionBuilder] instead, using following pattern:
///
///     // Declare a namespace class called `Actions` to group all Actions
///     // together.
///     class Actions {
///       // Declare constant field holding ActionBuilder for each action.
///       // Make sure to specify distinct names and type arguments.
///       static const ActionBuilder<Null> init = const ActionBuilder<Null>('init');
///       // If an action accepts a payload make sure to specify the payload type
///       static const ActionBuilder<Data> doWork = const ActionBuilder<Data>('doWork');
///     }
///
///     void main() {
///       // Execute an action:
///       store.trigger(Actions.init()); // no payload
///       store.trigger(Actions.doWork(data)); // with payload
///     }
class Action<T> {
  /// The name of this action.
  final String name;

  /// The payload of this action.
  final T payload;

  /// Creates new action with specified [name] and [payload].
  ///
  /// Instead of creating actions directly consider using [ActionBuilder].
  Action(this.name, this.payload);

  @override
  String toString() => 'Action{$name, $payload}';
}

/// Builder for actions.
///
/// Builder implements [Function] interface so that each `call` of a builder
/// returns a fresh [Action] instance. For instance:
///
///     const ActionBuilder<String> updateName =
///       const ActionBuilder<String>('updateName');
///     // `updateName` constant can now be executed as a function
///     Action action = updateName('John'); // Action('updateName', 'John');
///
/// See [Action] for more details and better usage example.
class ActionBuilder<T> implements Function {
  /// The action name for this builder.
  final String name;

  /// Creates new action builder for an action specified by unique [name].
  const ActionBuilder(this.name);

  /// Creates new [Action] with optional [payload].
  Action<T> call([T payload]) => new Action<T>(name, payload);
}

/// Signature for Redux reducer functions.
typedef Reducer<S, T> = S Function(S state, Action<T> action);

typedef StoreErrorHandler<S, T> = void Function(
    S state, Action<T> action, dynamic error);

/// Default error handler for state [Store].
///
/// This handler simply throws the [error] as unhandled.
void defaultStoreErrorHandler<S, T>(S state, Action<T> action, error) {
  throw error;
}

/// Builder for Redux state [Store].
class StoreBuilder<S> {
  StoreBuilder({S initialState, StoreErrorHandler<S, dynamic> onError})
      : _initialState = initialState,
        _onError = onError;
  S _initialState;
  StoreErrorHandler<S, dynamic> _onError;

  final Map<String, Reducer<S, dynamic>> _reducers = {};

  /// Binds [reducer] to specified [action] type.
  void bind<T>(ActionBuilder<T> action, Reducer<S, T> reducer) {
    _reducers[action.name] = reducer;
  }

  Store<S> build() => new Store._(_initialState, _reducers, _onError);
}

/// Redux State Store.
///
/// To create a new [Store] instance use [StoreBuilder].
class Store<S> {
  /// Creates a new [Store].
  Store._(S initialState, Map<String, Reducer<S, dynamic>> reducers,
      StoreErrorHandler<S, dynamic> onError)
      : _controller = new StreamController.broadcast(),
        _state = initialState,
        _reducers = reducers,
        _onError = onError ?? defaultStoreErrorHandler;

  final Map<String, Reducer<S, dynamic>> _reducers;
  final StreamController<StoreEvent<S, dynamic>> _controller;
  final StoreErrorHandler<S, dynamic> _onError;

  bool _disposed = false;

  /// Current state of this store.
  S get state => _state;
  S _state;

  /// Stream of all events occurred in this store.
  ///
  /// For only state changes see [changes] stream.
  Stream<StoreEvent<S, dynamic>> get events => _controller.stream;

  /// Stream of all events triggered by action type of [action].
  Stream<StoreEvent<S, T>> eventsWhere<T>(ActionBuilder<T> action) {
    assert(action != null);
    return events.where((event) => event.action.name == action.name).retype();
  }

  /// Stream of all state changes occurred in this store.
  ///
  /// State object must implement equality operator `==` as it is used to
  /// compare current and previous states.
  Stream<S> get changes => events.map((event) => event.newState).distinct();

  /// Stream of all changes for a part of application's state.
  ///
  /// [subState] function must return specific sub-state object from the
  /// application [state]. The sub-state class is responsible for implementing
  /// equality operator `==` as it is used to compare current and previous
  /// values of this type. Example:
  ///
  ///     enum HeadlampsMode { off, on, highBeams }
  ///     class Car {
  ///       HeadlampsMode headlamps;
  ///     }
  ///
  ///     Store<Car> store = getStore();
  ///     store.changesFor((Car state) => state.headlamps).listen((mode) {
  ///       print('Headlamps mode changed to $mode');
  ///     });
  Stream<T> changesFor<T>(T subState(S state)) =>
      changes.map(subState).distinct();

  /// Dispatches provided [action].
  void dispatch<T>(Action<T> action) {
    assert(!_disposed,
        'Dispatching actions is not allowed in disposed state Store.');
    final S oldState = _state;
    try {
      final reducer = _reducers[action.name];
      if (reducer != null) {
        _state = reducer(oldState, action);
      }
      _controller.add(new StoreEvent<S, T>(this, oldState, _state, action));
    } catch (err) {
      _onError(_state, action, err);
    }
  }

  /// Disposes this state store.
  ///
  /// Dispatching actions is not allowed after a state store is disposed.
  void dispose() {
    _disposed = true;
    _controller.close();
  }
}

/// Event triggered by an [action] in a Redux [Store].
class StoreEvent<S, T> {
  /// The state [Store] which produced this event.
  final Store<S> store;

  /// Application state before this event.
  final S oldState;

  /// Application state after this event.
  final S newState;

  /// The action which triggered this event.
  final Action<T> action;

  StoreEvent(this.store, this.oldState, this.newState, this.action);

  @override
  String toString() => "StoreEvent{$action, $oldState, $newState}";
}
