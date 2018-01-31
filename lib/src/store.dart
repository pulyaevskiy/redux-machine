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

/// Builder for Redux state [Store].
class StoreBuilder<S> {
  StoreBuilder({S initialState}) : _initialState = initialState;
  S _initialState;

  final Map<String, Reducer<S, dynamic>> _reducers = {};

  /// Binds [reducer] to specified [action] type.
  void bind<T>(ActionBuilder<T> action, Reducer<S, T> reducer) {
    _reducers[action.name] = reducer;
  }

  Store<S> build() => new Store._(_initialState, _reducers);
}

/// Redux State Store.
///
/// To create a new [Store] instance use [StoreBuilder].
class Store<S> {
  /// Creates a new [Store].
  Store._(S initialState, Map<String, Reducer<S, dynamic>> reducers)
      : _controller = new StreamController.broadcast(),
        _state = initialState,
        _reducers = reducers;

  final Map<String, Reducer<S, dynamic>> _reducers;
  final StreamController<StoreEvent<S, dynamic>> _controller;

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
    return events.where((event) => event.action.name == action.name);
  }

  /// Stream of all state changes occurred in this store.
  ///
  /// State object must implement equality operator `==` as it is used to
  /// compare current and previous states.
  Stream<S> get changes => events.map((event) => event.newState).distinct();

  /// Dispatches provided [action].
  void dispatch<T>(Action<T> action) {
    assert(!_disposed,
        'Dispatching actions is not allowed in disposed state Store.');
    final S oldState = _state;
    dynamic error;
    try {
      final reducer = _reducers[action.name];
      if (reducer != null) {
        _state = reducer(oldState, action);
      }
    } catch (err) {
      error = err;
    } finally {
      if (error != null) {
        _controller.addError(new StoreError(error, oldState, _state, action));
      } else
        _controller.add(new StoreEvent(oldState, _state, action));
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
  final S oldState;
  final S newState;
  final Action<T> action;

  StoreEvent(this.oldState, this.newState, this.action);

  @override
  String toString() => "StoreEvent{$action, $oldState, $newState}";
}

/// Error event triggered by an [action] in a Redux [Store].
class StoreError<S, T> extends Error {
  final dynamic error;
  final S oldState;
  final S newState;
  final Action<T> action;

  StoreError(this.error, this.oldState, this.newState, this.action);

  @override
  String toString() => "StoreError{$error, $action, $oldState, $newState}";
}
