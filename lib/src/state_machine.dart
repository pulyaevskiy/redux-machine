// Copyright (c) 2018, Anatoly Pulyaevskiy. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'store.dart';

/// State object used by [StateMachine] internally.
class MachineState<S> {
  /// Current application state.
  final S appState;

  /// Next action to invoke.
  final Action nextAction;

  MachineState(this.appState, this.nextAction);
}

/// Action dispatcher which is passed to [MachineReducer] functions.
class ActionDispatcher<T> implements Function {
  ActionDispatcher._();

  Action<T> get action => _action;
  Action<T> _action;
  bool _isDisposed = false;

  void call(Action<T> action) {
    assert(
        !_isDisposed,
        "Attempting to dispatch an action after ActionDispatcher has been"
        "disposed. This usually indicates you have asynchronous code in your "
        "reducer function.");
    assert(action != null);
    _action = action;
  }

  /// Disposes this action dispatcher.
  ///
  /// It is not allowed to invoke a dispatcher after it's disposed of.
  void dispose() {
    _isDisposed = true;
  }
}

/// Signature for reducer functions of [StateMachine].
typedef MachineReducer<S, T> = S Function(
    S state, Action<T> action, ActionDispatcher dispatch);

/// Builder for [StateMachine]s.
class StateMachineBuilder<S> {
  StateMachineBuilder({S initialState, StoreErrorHandler<S, dynamic> onError})
      : _builder = new StoreBuilder<MachineState<S>>(
            initialState: new MachineState(initialState, null),
            onError: (MachineState<S> state, Action action, error) {
              var handler = onError ?? defaultStoreErrorHandler;
              handler(state.appState, action, error);
              // If we are still here then user-provided handler decided to
              // not throw the error. However we rely on this in the dispatch
              // method so...
              throw error;
            });

  final StoreBuilder<MachineState<S>> _builder;

  /// Binds [action] to specified [reducer] function.
  void bind<T>(ActionBuilder<T> action, MachineReducer<S, T> reducer) {
    final storeReducer = (MachineState<S> state, Action<T> action) {
      var dispatcher = new ActionDispatcher._();
      final newAppState = reducer(state.appState, action, dispatcher);
      dispatcher.dispose();
      return new MachineState(newAppState, dispatcher.action);
    };
    _builder.bind(action, storeReducer);
  }

  /// Builds and returns new [StateMachine].
  StateMachine<S> build() => new StateMachine<S>._(_builder.build());
}

/// State machine which uses Redux data flow.
///
/// Use [StateMachineBuilder] to create a new [StateMachine].
///
/// To operate a StateMachine following three things are required:
/// - a state object
/// - action definitions
/// - reducer functions to handle actions
///
/// ## Defining state
///
/// You are free to use any object, this library does not impose any specific
/// interface to follow.
///
/// A good option could be to use `built_value` classes to reduce boilerplate.
///
/// For simple use cases consider following below example:
///
///     /// 1. Declare all fields as `final`.
///     /// 2. Define helper `copyWith` method to use in reducers
///     /// 3. Declare compound boolean getters for better semantics
///     /// 4. Implement `==` and `hashCode`.
///     class CarState {
///       final bool isEngineOn;
///       final double acceleration;
///       final double speed;
///       CarState(this.isEngineOn, this.acceleration, this.speed);
///
///       bool get isMoving => speed > 0.0;
///
///       CarState copyWith({
///         bool isEngineOn,
///         double acceleration,
///         double speed,
///       }) {
///         return new CarState(
///           isEngineOn ?? this.isEngineOn,
///           acceleration ?? this.acceleration,
///           speed ?? this.speed,
///         );
///       }
///     }
///
/// ## Defining actions
///
/// Actions must be declared using provided [Action] and [ActionBuilder] classes.
/// See documentation on [Action] class for a complete example.
///
/// ## Defining reducers
///
/// StateMachine reducer is any function which follows [MachineReducer]
/// interface. For more details see [MachineReducer] documentation.
///
/// ## Running StateMachine
///
/// When state, actions and reducers are defined we can create and run a state
/// machine:
///
///     abstract class Actions {
///       static const ActionBuilder<Null> engineOn =
///         const ActionBuilder<Null>('engineOn');
///       // more action definitions here.
///     }
///
///     CarState engineOnReducer(CarState state, Action<Null> action,
///       ActionDispatcher dispatcher) {
///       return state.copyWith(isEngineOn: true);
///     }
///
///     void main() {
///       final builder = new StateMachineBuilder<CarState>(
///         initialState: new CarState());
///       builder.bind(Actions.engineOn, engineOnReducer);
///
///       StateMachine<CarState> machine = builder.build();

///       // Trigger actions
///       machine.dispatch(Actions.engineOn());
///       // Dispose the machine when done
///       machine.dispose();
///     }
class StateMachine<S> implements Store<S> {
  StateMachine._(this._store);

  final Store<MachineState<S>> _store;

  @override
  S get state => _store.state.appState;

  @override
  Stream<StoreEvent<S, dynamic>> get events =>
      _store.events.map((event) => new StoreEvent(this, event.oldState.appState,
          event.newState.appState, event.action));

  // TODO: reduce code duplication by extracting all stream methods to a StoreBase class or mixin
  @override
  Stream<StoreEvent<S, T>> eventsWhere<T>(ActionBuilder<T> action) {
    assert(action != null);
    return events.where((event) => event.action.name == action.name);
  }

  @override
  Stream<S> get changes => events.map((event) => event.newState).distinct();

  @override
  Stream<T> changesFor<T>(T subState(S state)) =>
      changes.map(subState).distinct();

  @override
  void dispatch<T>(Action<T> action) {
    var currentAction = action;
    while (currentAction != null) {
      _store.dispatch(currentAction);
      if (currentAction.name == _store.state.nextAction?.name) {
        throw new StateError('Machine action attempts to trigger action '
            'of the same type: ${currentAction.name}');
      }
      currentAction = _store.state.nextAction;
      // Our onError handler always throws so if an error occurred during
      // dispatch we are guaranteed to exit this while loop.
      // One downside here is that current state might still have
      // `nextAction` set to the action which failed with error.
    }
  }

  @override
  void dispose() {
    _store.dispose();
  }
}
