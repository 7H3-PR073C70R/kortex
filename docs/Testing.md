# Testing in the Project

This document outlines best practices for testing in the project using `Mocktail` for mocking, and covers unit tests, widget tests, and integration tests. The key principles such as "Arrange-Act-Assert" are discussed, and dos and don'ts for each testing type are highlighted. Furthermore, the usage of `bloc_test` for testing BLoC and its states is described.

## Folder Structure

In the project, the `test` folder mirrors the architecture structure. Each test file is named after its corresponding source file, with the `_test.dart` suffix.

Example:
```bash
src/
├── features
│   └── sample_feature
│       └── presentation
│           └── bloc
│               └── sample_bloc.dart
test/
├── features
│   └── sample_feature
│       └── presentation
│           └── bloc
│               └── sample_bloc_test.dart
```

## Types of Tests and Their Importance

### 1. **Unit Tests**
   Unit tests focus on testing individual pieces of code in isolation, such as functions, methods, or small classes. In the project, unit tests are essential because they help ensure the smallest units of code behave as expected without needing external systems or UI interactions.

   **Why Unit Tests Are Needed**:
   - **Fast feedback**: Unit tests are quick to run and give immediate feedback on the smallest components of the system.
   - **Early detection**: Catch bugs early in development, especially in core logic.
   - **Refactoring safety**: They allow safe code refactoring since they ensure each unit of code still behaves correctly.

   **Dos and Don'ts**:
   - **Do**: Follow the Arrange-Act-Assert pattern.
   - **Do**: Use mocks for external dependencies like APIs, databases, or services.
   - **Don't**: Test UI components, since unit tests are meant for pure logic.

   **Example Code**:
   ```dart
   import 'package:flutter_test/flutter_test.dart';
   import 'package:mocktail/mocktail.dart';
   import 'package:my_app/features/sample_feature/domain/entities/sample_entity.dart';

   class MockRepository extends Mock implements SampleRepository {}

   void main() {
     late MockRepository mockRepository;

     setUp(() {
       mockRepository = MockRepository();
     });

     test('should return sample entity when getSample is called', () async {
       // Arrange
       final sampleEntity = SampleEntity(id: 1, name: 'Sample');
       when(() => mockRepository.getSample()).thenAnswer((_) async => sampleEntity);

       // Act
       final result = await mockRepository.getSample();

       // Assert
       expect(result, equals(sampleEntity));
     });
   }
   ```

### 2. **Widget Tests**
   Widget tests check the behavior of individual widgets by rendering them and simulating interactions.

   **Why Widget Tests Are Needed**:
   - **Isolate UI behavior**: They test individual components of the UI, ensuring the widget behaves as expected in various scenarios.
   - **User interaction validation**: Widget tests ensure the user interactions, like tapping buttons or scrolling lists, work as intended.
   - **UI consistency**: They help maintain the visual and behavioral consistency of the UI during development.

   **Dos and Don'ts**:
   - **Do**: Test individual UI components and user interactions.
   - **Do**: Use the `network_image_mock` package for testing widgets with network images.
   - **Don't**: Write business logic or complex calculations inside widgets.

   **Testing Network Images Using `network_image_mock`**:
   In the project, when testing widgets that rely on `Image.network` or `NetworkImageProvider`, use the `network_image_mock` package to mock the network requests and ensure proper testing.

   **Example Code**:
   ```dart
   import 'package:flutter_test/flutter_test.dart';
   import 'package:my_app/features/sample_feature/presentation/widgets/sample_widget.dart';
   import 'package:network_image_mock/network_image_mock.dart';

   void main() {
     testWidgets('should display network image correctly', (WidgetTester tester) async {
       mockNetworkImagesFor(() async {
         // Arrange
         await tester.pumpWidget(SampleWidget());

         // Act
         final imageFinder = find.byType(Image);

         // Assert
         expect(imageFinder, findsOneWidget);
       });
     });
   }
   ```

### 3. **Integration Tests**
   Integration tests validate the entire flow of the app by testing how components work together. Unlike unit and widget tests, integration tests check if the app behaves correctly as a whole. These tests are placed in the `integration_test` folder, **not** inside the `test` folder. In the project, the `integration_test` folder is structured based on features, similar to the `src` and `test` folder organization.

   **Why Integration Tests Are Needed**:
   - **End-to-end verification**: They simulate real user behavior and ensure all components, from UI to backend services, work together as expected.
   - **Complex interactions**: Help validate flows where multiple parts of the app interact, such as navigating between screens or saving data to a server.

   **Advantages**:
   - **High confidence**: Since it tests real-world scenarios, it gives the highest confidence in the app’s behavior.
   - **Full coverage**: It ensures that components and services work in unison, preventing integration errors that unit or widget tests may miss.

   **Disadvantages**:
   - **Slower execution**: Integration tests are typically slower than unit or widget tests, as they cover more ground.
   - **More complex to maintain**: As the app evolves, integration tests can become harder to maintain due to their broad coverage.

   **Example Code**:
   ```dart
   import 'package:flutter_test/flutter_test.dart';
   import 'package:integration_test/integration_test.dart';
   import 'package:my_app/main.dart' as app;

   void main() {
     IntegrationTestWidgetsFlutterBinding.ensureInitialized();

     testWidgets('app startup test', (WidgetTester tester) async {
       // Arrange
       app.main();
       await tester.pumpAndSettle();

       // Act
       final welcomeText = find.text('Welcome to MyApp');

       // Assert
       expect(welcomeText, findsOneWidget);
     });
   }
   ```

   **Folder Structure for Integration Tests**:
   ```bash
   integration_test/
   ├── features
   │   └── sample_feature
   │       └── sample_feature_test.dart
   ```

## Testing BLoC Using `bloc_test`
For testing BLoC and its states, `bloc_test` is a convenient library that helps in simulating events and verifying state transitions without the need to interact with the UI.

**Why Testing BLoC is Important**:
- **State verification**: BLoC manages business logic and state; verifying that it transitions correctly is crucial to ensuring application stability.
- **Decouples from UI**: Testing the BLoC ensures your business logic works regardless of how the UI changes.

**Example Code**:
```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/sample_feature/presentation/bloc/sample_bloc.dart';

void main() {
  blocTest<SampleBloc, SampleState>(
    'emits [SampleLoading, SampleLoaded] when SampleEvent is added',
    build: () => SampleBloc(),
    act: (bloc) => bloc.add(SampleEvent()),
    expect: () => [SampleLoading(), SampleLoaded()],
  );
}
```

## Arrange-Act-Assert Principle
This is a fundamental testing principle used across all test types.

- **Arrange**: Set up the necessary objects and initial conditions for the test.
- **Act**: Perform the action or behavior you want to test.
- **Assert**: Check that the expected outcome occurs as a result of the action.

## Summary of Testing Principles

### Unit Tests:
- **Do**:
  - Mock external dependencies.
  - Follow Arrange-Act-Assert.
- **Don't**:
  - Test UI components.

### Widget Tests:
- **Do**:
  - Test user interactions and widget behavior.
  - Use the `network_image_mock` package for testing network images.
- **Don't**:
  - Perform non-UI logic in widget tests.

### Integration Tests:
- **Do**:
  - Test entire app flows and user interactions.
  - Simulate complex interactions across multiple screens.
- **Don't**:
  - Place integration tests in the `test` folder. They belong in the `integration_test` folder.

By following these guidelines and utilizing the right testing strategies, the project will be better equipped to handle changes, catch bugs early, and ensure that the app behaves as expected under various scenarios.