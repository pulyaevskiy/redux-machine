// Copyright (c) 2017, Anatoly Pulyaevskiy. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// State machine which uses Redux flow.
library redux_machine;

import 'dart:async';

/// Redux action for state machine.
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
///       // Make sure to speficy distinct names.
///       static const ActionBuilder<Null> init = const ActionBuilder<Null>('init');
///       // If an action accepts a payload make sure to specify the payload type
///       static const ActionBuilder<Data> doWork = const ActionBuilder<Data>('doWork');
///     }
///
///     void main() {
///       // Execute an action:
///       machine.trigger(Actions.init()); // no payload
///       machine.trigger(Actions.doWork(data)); // with payload
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

/// State machine controller which allows triggering state transitions from
/// within reducer functions.
///
/// An instance of [MachineController] is passed to every [ReduxMachineReducer]
/// function, which may use it to trigger another action after this reducer
/// returns updated state. It is not required for a reducer to use this
/// controller.
///
/// See [ReduxMachineReducer] for more details on reducers.
class MachineController<T> {
  /// Action to execute after current action.
  Action<T> get action => _action;
  Action<T> _action;

  /// Schedules [action] to be executed after current reducer completes.
  void become(Action<T> action) {
    _action = action;
  }
}

/// Reducer function type for [ReduxMachine].
///
/// Reducer function receives current state of [ReduxMachine], applies
/// specified [action] and returns updated state as a result.
///
/// Optionally can use [controller] to schedule another action after this reducer
/// returns new state. Scheduled action is triggered right after this reducer
/// completes.
///
/// It is not allowed to schedule an action of the same type (having the same
/// name) as current [action]. If this happens `ReduxMachine` throws [StateError].
typedef S ReduxMachineReducer<S, T>(
    S state, Action<T> action, MachineController controller);

/// Shutdown callback type definition for [ReduxMachine].
typedef void ShutdownCallback();

/// Redux powered state machine.
///
/// To operate a ReduxMachine following three things are required:
/// - a state object
/// - action definitions
/// - reducer functions to handle actions
///
/// ## Defining state
///
/// You are free to use any object, this library does not impose any specific
/// interface to follow. As a guidance consider following example:
///
///     /// 1. Declare all fields as `final`.
///     /// 2. Define helper `copyWith` method to use in reducers
///     /// 3. Declare compound boolean getters for better semantics
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
/// See documention on [Action] class for a complete example.
///
/// ## Defining reducers
///
/// ReduxMachine reducer is any function which follows [ReduxMachineReducer]
/// interface. For more details see [ReduxMachineReducer] documentation.
///
/// ## Running ReduxMachine
///
/// When state, actions and reducers are defined we can create and run a state
/// machine:
///
///     class Actions {
///       static const ActionBuilder<Null> engineOn = const ActionBuilder<Null>('engineOn');
///       // more action definitions here.
///     }
///
///     CarState engineOnReducer(CarState state, Action<Null> action,
///       MachineController controller) {
///       return state.copyWith(isEngineOn: true);
///     }
///
///     void main() {
///       ReduxMachine<CarState> machine = new ReduxMachine<CarState>();
///       // Register all reducer functions
///       machine..addReducer(Actions.engineOn, engineOnReducer);
///       // Start the machine with initial state
///       machine.start(new CarState(/* values */));
///       // Trigger actions
///       machine.trigger(Actions.engineOn());
///       // Shutdown the machine when done
///       machine.shutdown();
///     }
class ReduxMachine<S> extends Stream<S> {
  ReduxMachine({void onShutdown()}) : onShutdown = onShutdown;

  /// Shutdown callback which is executed by this machine before it terminates.
  ///
  /// For more details see [shutdown].
  final ShutdownCallback onShutdown;

  final Map<String, ReduxMachineReducer<S, dynamic>> _reducers =
      new Map<String, ReduxMachineReducer<S, dynamic>>();
  final StreamController<S> _controller = new StreamController.broadcast();

  /// Whether this machine has been started using [start].
  bool get isStarted => _isStarted;
  bool _isStarted = false;

  bool _isDisposed = false;

  /// Current state of this machine.
  S get state => _state;
  S _state;

  void addReducer<T>(
      ActionBuilder<T> action, ReduxMachineReducer<S, T> reducer) {
    assert(!_isStarted,
        'Reducers can not be registered after ReduxMachine started.');
    assert(!_reducers.containsKey(action.name));
    _reducers[action.name] = reducer;
  }

  /// Initializes this state machine with [initialState] and triggers
  /// [initialAction] if provided.
  void start(S initialState, [Action<dynamic> initialAction]) {
    assert(!_isStarted);
    _isStarted = true;
    _state = initialState;
    if (initialAction != null) trigger(initialAction);
  }

  /// Shuts down this state machine.
  ///
  /// If [onShutdown] is not `null` it's called first. At this point it is
  /// still allowed to trigger any action to cleanup state and release any
  /// allocated resources (stop stream subscriptions, for instance).
  ///
  /// After `shutdown` is called this state machine is considered disposed and
  /// further action triggers will not be allowed.
  void shutdown() {
    assert(!_isDisposed);
    if (onShutdown != null) onShutdown();
    _controller.close();
    _isDisposed = true;
  }

  /// Triggers [action].
  ///
  /// Triggering an action before machine started is not allowed, use [start]
  /// before calling this method.
  void trigger(Action<dynamic> action) {
    assert(_isStarted && !_isDisposed);
    Action currentAction = action;
    while (currentAction != null) {
      final MachineController controller = new MachineController();
      final ReduxMachineReducer<S, dynamic> reducer =
          _reducers[currentAction.name];
      assert(
          reducer != null, 'No registered reducer for action $currentAction');
      S _previousState = _state;
      _state = reducer(_state, currentAction, controller);
      if (_state != _previousState) _controller.add(_state);
      if (currentAction.name == controller.action?.name) {
        throw new StateError(
            'Machine action attempts to trigger action of the same type');
      }
      currentAction = controller.action;
    }
  }

  @override
  StreamSubscription<S> listen(void onData(S event),
      {Function onError, void onDone(), bool cancelOnError}) {
    return _controller.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
}
