// Copyright (c) 2017, Anatoly Pulyaevskiy. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// State machine which uses Redux flow.
library redux_machine;

import 'dart:async';
import 'src/store.dart';

export 'src/store.dart';
export 'src/state_machine.dart';

/// State machine controller which allows triggering state transitions from
/// within reducer functions.
///
/// An instance of [MachineController] is passed to every [ReduxMachineReducer]
/// function, which may use it to trigger another action after this reducer
/// returns updated state. It is not required for a reducer to use this
/// controller.
///
/// See [ReduxMachineReducer] for more details on reducers.
@Deprecated('To be removed in 1.0.0. Consider switching to StateMachine.')
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
@Deprecated('To be removed in 1.0.0. Consider switching to StateMachine.')
typedef S ReduxMachineReducer<S, T>(
    S state, Action<T> action, MachineController controller);

/// Shutdown callback type definition for [ReduxMachine].
@Deprecated('To be removed in 1.0.0. Consider switching to StateMachine.')
typedef void ShutdownCallback();

/// Redux powered state machine.
///
/// This class is deprecated, consider switching to [StateMachine].
@Deprecated('To be removed in 1.0.0. Consider switching to StateMachine.')
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
