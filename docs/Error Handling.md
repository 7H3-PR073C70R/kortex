### Error Handling Documentation

Error handling is an essential aspect of building reliable applications, especially when working with external resources such as APIs. This documentation will cover the importance of proper error management, the use of the `Either` type, and how the `makeRequest` extension enhances the error-handling process. We'll also discuss how this approach improves efficiency and decouples the error logic from the higher layers.

#### Centralized Error Handling in the Repository
In a clean architecture setup, repositories handle the communication between data sources (such as APIs) and the business logic. It’s essential to manage errors centrally at this layer to keep the rest of the project clean and decoupled from exception handling. Keeping `try-catch` blocks inside the repository ensures that external errors like network failures or invalid responses are encapsulated, allowing higher layers like Bloc or use cases to only deal with the result (either success or failure) without concerning themselves with how the error occurred.

This approach leads to:
- **Better Separation of Concerns**: The business logic or UI layers don’t need to worry about the details of error handling. They only process the result of a repository call.
- **Consistency**: All errors, regardless of their source (network, server, etc.), are managed consistently across the project.

#### Simplified Error Handling with `makeRequest`
The `makeRequest` extension centralizes error management for asynchronous operations, catching exceptions and returning an `Either` type. By simplifying this process, the project avoids repetitive `try-catch` blocks scattered throughout the codebase.

##### Why `makeRequest` is Efficient:
1. **Unified Handling**: The extension allows any repository method to handle errors consistently, whether the error is from the network (`DioException`) or a custom server error (`ServerException`).
2. **Optional Callbacks**: You can pass success and failure callbacks to handle actions immediately after the response without complicating the repository code.
3. **Error Logging**: It logs exceptions and stack traces in debug mode, which is useful for diagnostics during development while ensuring that such logs are excluded in production code.

Here’s how `makeRequest` works:

```dart
extension RepositoryExtension<T> on Future<T> {
  Future<Either<Failure, T>> makeRequest({
    ValueChanged<T>? onSuccess,
    VoidCallback? onFailure,
  }) async {
    try {
      final data = await this;
      onSuccess?.call(data);
      return Right(data);
    } on DioException catch (e, s) {
      debugPrint(e.toString());
      debugPrint(s.toString());
      return Left(ServerFailure(message: e.errorMessage));
    } on ServerException catch (e, s) {
      onFailure?.call();
      debugPrint(e.toString());
      debugPrint(s.toString());
      return Left(ServerFailure(message: e.errorMessage));
    } catch (e, s) {
      onFailure?.call();
      debugPrint(e.toString());
      debugPrint(s.toString());
      return const Left(ServerFailure(message: 'Something went wrong.'));
    }
  }
}
```

With this in place, the project can handle any type of exception through a simple, reusable extension that returns either a success (`Right`) or failure (`Left`).

#### The Role of `Either`
The `Either` type is crucial for functional error handling, as it encapsulates a disjoint union of two types: `Left` for failure and `Right` for success. This abstraction allows the project to handle both success and failure scenarios without using exceptions directly in the business or presentation layers.

##### Why `Either` is Efficient:
1. **Encapsulation**: Instead of throwing errors or returning null, the result is encapsulated in `Either`, ensuring the consumer must handle both success and failure.
2. **Declarative Handling**: Using `fold`, developers can declaratively handle both the failure (`Left`) and success (`Right`) cases in a single flow.

Here’s an example of using `fold` with `Either`:

```dart
final response = await repository.fetchData();

response.fold(
  (failure) {
    // Handle failure
    print('Error: ${failure.message}');
  },
  (data) {
    // Handle success
    print('Data: $data');
  },
);
```

In this example, the `fold` method allows the handling of success and failure within the same flow, promoting a clean and structured way of managing outcomes.

#### Error Handling Extension (`ErrorHandler`)
The `ErrorHandler` extension converts specific exceptions into meaningful messages that can be displayed to the user. This ensures that users are presented with actionable and informative error messages, improving the overall experience.

```dart
extension ErrorHandler on Exception {
  String? get errorMessage {
    try {
      final error = this as DioException;
      final backendMessage = (error.response?.data as Map?)?['message'] as String?;
      final message = backendMessage ?? error.message ?? 'Something went wrong';
      return message.toLowerCase().contains('failed host lookup')
          ? 'Please check your internet connection.'
          : message;
    } catch (e) {
      return null;
    }
  }
}
```

With this extension, you can map network or server errors into user-friendly messages while logging technical details for developers.

#### How the Architecture Stays Decoupled
By utilizing these abstractions (i.e., `Either`, `makeRequest`), error handling is fully decoupled from the business logic and UI layers (e.g., Bloc, use cases). These layers are not aware of the underlying network calls or how errors are managed; they only receive the result of a repository call, which is either a `Left` (failure) or `Right` (success).

#### Conclusion
This approach to error handling through `Either`, `makeRequest`, and the `ErrorHandler` extension ensures that the project:
- Maintains a clean separation of concerns.
- Has consistent error management across repositories.
- Provides clear and structured handling of results using `fold`.
- Is scalable, with reusable error-handling logic applied across all network calls.

By handling errors this way, the project remains clean, maintainable, and easy to scale. The UI and business logic are decoupled from the error details, simplifying both debugging and feature development.

