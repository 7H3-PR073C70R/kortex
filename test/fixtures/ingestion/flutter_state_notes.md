Flutter State Management Notes

State is any data that can change over the lifetime of a widget. A StatefulWidget stores mutable state inside its State object. Calling setState tells the framework that the state changed and the widget must rebuild.

Immutable widgets are cheap to rebuild because Flutter only diffs the element tree. The BuildContext refers to the location of a widget in the tree.

Example: counter

```dart
class Counter extends StatefulWidget {
  const Counter({super.key});
  @override
  State<Counter> createState() => _CounterState();
}
```

BLoC separates business logic from the UI using streams of events and states.
Cubit is a simplified BLoC that exposes functions instead of events.

Tips
- Keep build methods free of side effects.
- Use const constructors where possible.
- Dispose controllers in dispose().
