// Copyright (c) 2017, Anatoly Pulyaevskiy. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// State machine powered by Redux flow.
library redux_machine;

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
///       static const ActionBuilder<Null> init = const ActionBuilder('init');
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
}

/// Builder for actions.
///
/// Builder implements [Function] interface so that each call of a builder
/// returns a fresh [Action] instance. For instance:
///
///     const ActionBuilder<String> updateName =
///       const ActionBuilder<String>('updateName');
///     // `updateName` constant can now be executed as a function
///     Action action = updateName('John');
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
  Action<T> get action => _action;
  Action<T> _action;

  /// Schedules [action] to be executed after current state machine reducer
  /// completes.
  void become(Action<T> action) {
    _action = action;
  }
}

typedef S ReduxMachineReducer<S, T>(
    S state, Action<T> action, MachineController controller);

/// Redux powered state machine.
class ReduxMachine<S> {
  bool _isStarted = false;
  final Map<String, ReduxMachineReducer<S, Null>> _reducers;

  ReduxMachine(Map<String, ReduxMachineReducer<S, Null>> reducers)
      : _reducers = new Map<String, ReduxMachineReducer<S, Null>>.unmodifiable(
            reducers);

  /// Whether this machine has been started using [start].
  bool get isStarted => _isStarted;

  /// Current state of this machine.
  S get state => _state;
  S _state;

  void start(S initialState, [Action initialAction]) {
    assert(!_isStarted);
    _isStarted = true;
    _state = initialState;
    if (initialAction != null) trigger(initialAction);
  }

  void trigger(Action action) {
    assert(_isStarted);
    Action currentAction = action;
    while (currentAction != null) {
      final MachineController controller = new MachineController();
      final ReduxMachineReducer<S, dynamic> reducer =
          _reducers[currentAction.name];
      assert(reducer != null);
      _state = reducer(_state, currentAction, controller);
      if (currentAction.name == controller.action?.name) {
        throw new StateError(
            'Machine action attempts to trigger action of the same type');
      }
      currentAction = controller.action;
    }
  }
}
