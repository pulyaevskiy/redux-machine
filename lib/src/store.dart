// Copyright (c) 2018, Anatoly Pulyaevskiy. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';

/// Redux action.
///
/// Actions trigger state transitions and are normally handled by a reducer
/// function.
///
/// While you can create an action by instantiating it directly it is recommended
/// to use one of [ActionBuilder] classes instead, using following pattern:
///
///     // Declare a namespace class called `Actions` to group all actions
///     // together.
///     abstract class Actions {
///       // Declare constant field holding ActionBuilder for each action.
///       // Make sure to specify distinct names and type arguments.
///       static const init = const VoidActionBuilder('init');
///       // If an action accepts a payload make sure to specify the payload type:
///       static const doWork = const ActionBuilder<Data>('doWork');
///     }
///
///     void main() {
///       // Execute an action:
///       store.dispatch(Actions.init()); // no payload
///       store.dispatch(Actions.doWork(data)); // with payload
///     }
///
/// An action can instruct state store to synchronously dispatch another action
/// right after it using [next] method. This allows Redux store to behave like
/// a state machine which reacts to state transitions according to logic in
/// reducer functions.
class Action<T> {
  /// The name of this action.
  final String name;

  /// The payload of this action.
  final T payload;

  /// Creates new action with specified [name] and [payload].
  ///
  /// Instead of creating actions directly consider using one of [ActionBuilder]
  /// classes.
  Action(this.name, this.payload);

  Action _next;

  /// Whether this action wants to dispatch another action right after it.
  bool get hasNext => _next != null;

  /// Schedules [action] to be dispatched right after this action.
  S next<R, S>(Action<R> action, S state) {
    _next = action;
    return state;
  }

  @override
  String toString() => '$runtimeType{$name, $payload}';

  StoreEvent<S, T> _toEvent<S>(Store store, S oldState, S newState) {
    return new StoreEvent<S, T>(store, oldState, newState, this);
  }

  StoreError<S, T> _toError<S>(Store<S> store, S state, error) {
    return new StoreError<S, T>(error, this, state, store);
  }
}

/// Asynchronous action with a `Future`.
///
/// Provides a way for dispatching side (usually UI) to be notified when
/// asynchronous work associated with this action is done.
///
/// Use `Future` provided by [done] field to wait for the result. Note that
/// this Future contains `void` and does not allow returning a value back
/// to dispatching code. This is by design as data should normally be
/// retrieved from updated state object via [Store.changes] or [Store.changesFor]
/// subscriptions. The Future can be completed with an error.
///
/// The side which actually performs async operation can call [complete] and
/// [completeError] to indicate when the work is done.
class AsyncAction<T> extends Action<T> {
  AsyncAction(String name, T payload) : super(name, payload);

  final Completer<void> _completer = new Completer<void>();

  /// Completes this action.
  void complete() => _completer.complete();

  /// Completes this action with error.
  void completeError(error) => _completer.completeError(error);

  /// Future which indicates when asynchronous work for this action is done.
  Future<void> get done => _completer.future;

  /// Returns `true` if this action has been completed with either success or
  /// error.
  bool get isDone => _completer.isCompleted;
}

abstract class ActionName<T> {
  final String name;
  const ActionName(this.name);
}

/// Builder for actions carrying non-empty payload.
///
/// For actions without any payload consider using [VoidActionBuilder].
///
/// Builder implements [Function] interface so that each `call` of a builder
/// returns a fresh [Action] instance. For instance:
///
///     const updateName = const ActionBuilder<String>('updateName');
///     // `updateName` constant can now be executed as a function
///     final action = updateName('John'); // Action('updateName', 'John');
///
/// See [Action] for more details and better usage example.
///
/// See also:
/// - [AsyncActionBuilder] - for actions that trigger async work.
/// - [AsyncVoidActionBuilder] - for actions with no payload and async work.
class ActionBuilder<T> extends ActionName<T> {
  /// Creates new action builder for an action specified by unique [name].
  const ActionBuilder(String name) : super(name);

  /// Creates new [Action] with non-empty [payload].
  Action<T> call(T payload) => new Action<T>(name, payload);
}

/// Builder for actions carrying empty (`void`) payload.
///
/// For actions with non-empty payload consider using [ActionBuilder].
///
/// See also:
/// - [AsyncActionBuilder] - for actions that trigger async work.
/// - [AsyncVoidActionBuilder] - for actions with no payload and trigger async work.
class VoidActionBuilder extends ActionName<void> {
  const VoidActionBuilder(String name) : super(name);

  /// Creates new action with no payload.
  Action<void> call() => new Action<void>(name, null);
}

/// Builder for [AsyncAction]s carrying non-empty payload.
///
/// For async actions without any payload consider using [AsyncVoidActionBuilder].
class AsyncActionBuilder<T> extends ActionName<T> {
  /// Creates new action builder for an action specified by unique [name].
  const AsyncActionBuilder(String name) : super(name);

  /// Creates new [AsyncAction] with [payload].
  AsyncAction<T> call(T payload) => new AsyncAction<T>(name, payload);
}

/// Builder for [AsyncAction]s carrying empty (`void`) payload.
///
/// For async actions with non-empty payload consider using [AsyncActionBuilder].
class AsyncVoidActionBuilder extends ActionName<void> {
  const AsyncVoidActionBuilder(String name) : super(name);

  /// Creates new [AsyncAction] with no payload.
  AsyncAction<void> call() => new AsyncAction<void>(name, null);
}

/// Signature for Redux reducer functions.
typedef Reducer<S, T> = S Function(S state, Action<T> action);

/// Builder for Redux state [Store].
class StoreBuilder<S> {
  StoreBuilder({S initialState}) : _initialState = initialState;
  S _initialState;

  final Map<String, dynamic> _reducers = {};

  /// Binds [reducer] to specified [action].
  ///
  /// [action] argument can be one of action builders:
  ///
  /// - [ActionBuilder] - for regular actions with non-empty payload.
  /// - [VoidActionBuilder] - for regular actions with empty (`void`) payload.
  /// - [AsyncActionBuilder] - for async actions with non-empty payload.
  /// - [VoidActionBuilder] - for async actions with empty (`void`) payload.
  void bind<T, A>(covariant ActionName<T> action, Reducer<S, T> reducer) {
    _reducers[action.name] = reducer;
  }

  Store<S> build() => new Store._(_initialState, _reducers);
}

/// Redux State Store.
///
/// To create a new [Store] instance use [StoreBuilder].
class Store<S> {
  /// Creates a new [Store].
  Store._(S initialState, Map<String, dynamic> reducers)
      : _controller = new StreamController.broadcast(),
        _errors = new StreamController<StoreError<S, dynamic>>.broadcast(),
        _state = initialState,
        _reducers = reducers;

  final Map<String, dynamic> _reducers;
  final StreamController<StoreEvent<S, dynamic>> _controller;
  final StreamController<StoreError<S, dynamic>> _errors;

  bool _disposed = false;

  /// Current state of this store.
  S get state => _state;
  S _state;

  /// Stream of all errors occurred in this store.
  ///
  /// If there is no listener on this stream then errors are rethrown
  /// synchronously during dispatch.
  Stream get errors => _errors.stream;

  /// Stream of all events occurred in this store.
  ///
  /// For only state changes see [changes] stream.
  Stream<StoreEvent<S, dynamic>> get events => _controller.stream;

  /// Stream of all events triggered by actions of type [action].
  Stream<StoreEvent<S, T>> eventsFor<T>(ActionName<T> action) {
    assert(action != null);
    return events.where((event) => event.action.name == action.name).cast();
  }

  @Deprecated('Use "eventsFor" instead')
  Stream<StoreEvent<S, T>> eventsWhere<T>(ActionName<T> action) =>
      eventsFor<T>(action);

  /// Stream of all state changes occurred in this store.
  ///
  /// State object must implement equality operator `==` as it is used to
  /// compare current and previous states.
  Stream<S> get changes => events.map((event) => event.newState).distinct();

  /// Stream of all changes for a part of application's state.
  ///
  /// [mapper] function must return specific sub-state object from the
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
  Stream<T> changesFor<T>(T mapper(S state)) => changes.map(mapper).distinct();

  /// Dispatches provided [action].
  ///
  /// Executes reducer function registered for the [action] and publishes
  /// [StoreEvent] to the [events] stream. If there is no reducer function
  /// registered for [action] a [StoreEvent] is still published with "old" and
  /// "new" state values referencing the same instance of state object.
  ///
  /// If reducer function throws an error it is forwarded to the [errors] stream
  /// only if there is active listener on this stream. If there is no active
  /// listener for errors the error is rethrown synchronously.
  void dispatch(Action action) {
    var current = action;
    if (!_dispatch(current)) return;

    while (current.hasNext) {
      if (current.name == current._next.name)
        throw new StateError('Store Action attempts to dispatch an action '
            'of the same type "${current.name}" which can '
            'cause an infinite loop and therefore forbidden.');
      current = current._next;
      if (!_dispatch(current)) {
        /// If [_dispatch] call failed with an error which was published to
        /// the events stream the error will surface at a later iteration of
        /// the event loop. We must exit our while-loop here or otherwise it will
        /// run forever.
        break;
      }
    }
  }

  /// Internal dispatch method which returns `false` in case of an error.
  bool _dispatch(Action action) {
    assert(!_disposed,
        'Dispatching actions is not allowed in disposed state Store.');
    final S oldState = _state;
    try {
      final reducer = _reducers[action.name];
      if (reducer != null) {
        _state = reducer(oldState, action);
      }
      _controller.add(action._toEvent<S>(this, oldState, _state));
      return true;
    } catch (err, stackTrace) {
      if (_errors.hasListener) {
        _errors.addError(action._toError<S>(this, _state, err), stackTrace);
        return false;
      }
      rethrow;
    }
  }

  /// Disposes this state store.
  ///
  /// Dispatching actions is not allowed after a state store is disposed.
  void dispose() {
    _disposed = true;
    _controller.close();
    _errors.close();
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
  String toString() => "$runtimeType{$action, $oldState, $newState}";
}

/// An unhandled error occurred during action dispatch.
///
/// See also:
/// - [Store.errors] - a stream of all unhandled errors.
class StoreError<S, T> {
  final error;
  final Action<T> action;
  final S state;
  final Store<S> store;

  StoreError(this.error, this.action, this.state, this.store);

  @override
  String toString() => "$runtimeType{$error, $action, $state}";
}

/// State object interface required for [StateMachine].
@deprecated
abstract class MachineState<T> {
  MachineState(this.nextAction);

  /// Next action to invoke.
  final Action<T> nextAction;
}

/// Builder for [StateMachine]s.
@deprecated
class StateMachineBuilder<S extends MachineState> extends StoreBuilder<S> {
  StateMachineBuilder({S initialState}) : super(initialState: initialState);

  StateMachine<S> build() => new StateMachine<S>(_initialState, _reducers);
}

/// State machine which uses Redux data flow.
///
/// Use [StateMachineBuilder] to create a new [StateMachine].
///
/// To operate a StateMachine following three things are required:
/// - a state object which extends base [MachineState] class.
/// - action definitions
/// - reducer functions to handle actions
///
/// ## Defining state
///
/// [StateMachine] requires state objects to extend special [MachineState] base
/// class which contains one extra property - [MachineState.nextAction]. A
/// reducer may use this property to dispatch another Redux action after it's
/// done.
///
/// For simple use cases consider following below example:
///
///     /// 1. Declare all fields as `final`.
///     /// 2. Define helper `copyWith` method to use in reducers
///     /// 3. Declare compound boolean getters for better semantics
///     /// 4. Implement `==` and `hashCode`.
///     class CarState<T> extends MachineState<T> {
///       final bool isEngineOn;
///       final double acceleration;
///       final double speed;
///       CarState({
///         this.isEngineOn,
///         this.acceleration,
///         this.speed,
///         Action<T> nextAction,
///       }): super(nextAction);
///
///       bool get isMoving => speed > 0.0;
///
///       CarState<R> copyWith<R>({
///         bool isEngineOn,
///         double acceleration,
///         double speed,
///         Action<R> nextAction,
///       }) {
///         return new CarState<R>(
///           isEngineOn: isEngineOn ?? this.isEngineOn,
///           acceleration: acceleration ?? this.acceleration,
///           speed: speed ?? this.speed,
///           nextAction,
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
/// StateMachine reducer is any function which follows [Reducer] interface.
/// For more details see [Reducer] documentation.
///
/// ## Running StateMachine
///
/// When state, actions and reducers are defined we can create and run a state
/// machine:
///
///     abstract class Actions {
///       static const engineOn = const ActionBuilder<void>('engineOn');
///       // more action definitions here.
///     }
///
///     CarState engineOnReducer(CarState state, Action<void> action) {
///       return state.copyWith(isEngineOn: true);
///     }
///
///     void main() {
///       final builder = new StateMachineBuilder<CarState>(
///         initialState: new CarState());
///       builder.bind(Actions.engineOn, engineOnReducer);
///
///       StateMachine<CarState> machine = builder.build();

///       // Dispatch actions
///       machine.dispatch(Actions.engineOn());
///       // Dispose the machine when done
///       machine.dispose();
///     }
@deprecated
class StateMachine<S extends MachineState> extends Store<S> {
  StateMachine(S initialState, Map<String, dynamic> reducers)
      : super._(initialState, reducers);

  @override
  void dispatch(Action action) {
    var currentAction = action;
    _dispatch(action);
    while (true) {
      if (state.nextAction == null) break;
      if (currentAction.name == state.nextAction?.name)
        throw new StateError(
            'StateMachine action attempts to dispatch an action '
            'of the same type "${currentAction.name}" which can '
            'cause an infinite loop and therefore forbidden.');
      currentAction = state.nextAction;
      if (!_dispatch(state.nextAction)) {
        /// If [_dispatch] call failed with an error which was published to
        /// the events stream the error will surface at a later iteration of
        /// the event loop. We must exit our while-loop here or otherwise it will
        /// run forever.
        break;
      }
    }
  }
}
