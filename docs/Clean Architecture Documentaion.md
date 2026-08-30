### Comprehensive Documentation on Choosing Clean Architecture For The Project

---

### Clean Architecture (Proposed by Uncle Bob)

This architecture focuses on separating the concerns of different parts of the application, ensuring that the core business logic is isolated from the user interface and the external dependencies.

#### Key Folder Structures in Clean Architecture

The folder structure in this project is designed to follow the principles of Clean Architecture, which separates the code into distinct layers:

1. **Feature Layer**: This is where I group everything related to specific functionalities or features of the project. The feature layer itself is further divided into:

   - **Data**: 
     - **Client:** Located within the data layer, the client folder focuses on API integration, leveraging Retrofit to simplify the process of making network requests and handling responses. By using Retrofit, the project can streamline API calls, allowing more focus on feature development. We shall discuss more about retrofit later in this documentation and it usage.
     - **Data Source**: This folder contains the implementations for accessing data from different sources (e.g., APIs(client), local databases). For instance, We might have a `RemoteDataSource` that fetches data from a REST API by depending on the client.
     - **Model**: The `Model` folder holds the data structures (or models) that we use throughout the data layer. These models are often the representations of the JSON responses from APIs. We will be using freezed and json_serializer for the model generation.
     - **Repository (Implementation)**: This folder includes the concrete implementations of repositories, which manage data operations and decide where to get or store data. Makes use of either to minimize the use of try & catch.

   - **Domain**: 
     <!-- - **Entities**: The entities represent the core objects that are central to the business logic. These are simple data classes that define the properties of the objects in the project -->
     - **Repository (Abstract)**: Here, We define abstract classes that act as contracts for the repository implementations. This allows the domain layer to be independent of data sources.
     - **Use Cases**: The use cases are the heart of the business logic. They represent specific actions or processes that can be performed within the application (e.g., `GetUserProfile`, `SubmitOrder`).

   - **Presentation**: 
     - **Bloc/Cubit**: In this folder, We manage the state of the UI components using Bloc or Cubit, which helps in managing complex state logic. The bloc is directly dependant on the Use Cases to perform actions that needs to data.
     - **Pages**: The `Pages` folder contains the UI screens that users interact with. (e.g., `ProfilePage`, `OrderPage`)
     - **Widgets**: Here, We store reusable UI components that can be shared across different pages and are directly used in the feature otherwise the widgets will be stored in the shared folder.

#### Connections Between Folders

- **Data Layer**: The data sources interact with external systems (e.g., APIs, local databases). They send data to the repositories, which decide whether to use this data or fetch it from another source. The repositories then return this data to the domain layer.

- **Domain Layer**: The use cases in the domain layer receive data from the repositories. The use cases process this data and implement the business logic. The results are then passed to the presentation layer.

- **Presentation Layer**: The UI components observe changes from the Bloc/Cubit, which are driven by the use cases. These components update the UI based on the latest state from the business logic.

By adhering to this structure, We ensure that each layer is independent and easily testable. The separation of concerns allows for better maintainability and scalability as the project grows.

### Why we choose to use Flutter Hooks and it importance in the Project

Flutter Hooks have been a game-changer in managing the lifecycle of stateful widgets without the boilerplate code that usually comes with them. Hooks provide a way to manage side effects, such as creating and disposing of `TextEditingController`, in a much cleaner and more organized manner.

#### Example: Creating a Text Controller with Hooks

```dart
import 'package:flutter_hooks/flutter_hooks.dart';

class MyTextField extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final textController = useTextEditingController();

    return TextField(
      controller: textController,
      decoration: InputDecoration(
        labelText: 'Enter Text',
      ),
    );
  }
}
```

In this example, `useTextEditingController()` is a hook that creates a `TextEditingController` and automatically disposes of it when the widget is removed from the tree. This approach reduces the risk of memory leaks and simplifies the code.

### Proposed Project structure

```dart
│
├── src
│   ├── app
│   │   ├── page
│   │   │   └── app.dart
│   │   └── router
│   │       └── app_router.dart
│   ├── core
│   │   ├── constants
│   │   │   ├── app_colors.dart
│   │   │   ├── app_env.dart
│   │   │   ├── app_spacing.dart
│   │   │   ├── app_strings.dart
│   │   │   └── pref_keys.dart
│   │   ├── enums
│   │   │   └── environment.dart
│   │   ├── error
│   │   ├── extensions
│   │   ├── helpers
│   │   ├── networking
│   │   │   ├── api
│   │   │   │   └── app_api_endpoint.dart
│   │   │   └── interceptors
│   │   │       └── dio_interceptors.dart
│   │   ├── themes
│   │   │   └── app_theme.dart
│   │   └── utils
│   ├── di
│   │   ├── client_locator.dart
│   │   ├── data_source_locator.dart
│   │   ├── external_locator.dart
│   │   ├── locator.dart
│   │   ├── repository_locator.dart
│   │   ├── service_locator.dart
│   │   └── use_case_locator.dart
│   ├── features
│   │   ├── sample_feature
│   │   │   ├── data
│   │   │   │   ├── client
│   │   │   │   ├── data_sources
│   │   │   │   ├── models
│   │   │   │   └── repositories 
│   │   │   ├── domain
│   │   │   │   ├── entities
│   │   │   │   ├── repositories 
│   │   │   │   └── use_cases
│   │   │   └── presentation
│   │   │       ├── bloc
│   │   │       ├── pages
│   │   │       └── widgets
│   ├── gen
│   │   └── assets.gen.dart
│   ├── l10n
│   │   ├── arb
│   │   │   └── app_en.arb
│   │   └── l10n.dart
│   ├── services
│   ├── shared
│   │   ├── widgets
│   │   └── wrappers
│   └── bootstrap.dart
│
├── main_development.dart
├── main_staging.dart
├── main_production.dart
└── test
    ├── features
    ├── core
    └── main_test.dart
      
```

Choosing this project structure offers several advantages, particularly in terms of maintainability, scalability, and clear separation of concerns. Here’s a brief explanation of why this structure is beneficial and an overview of its components:

### **Advantages of This Project Structure**

1. **Separation of Concerns:**
   - **Features Division:** By organizing code into `features`, `core`, and `shared`, you ensure that different parts of the application have well-defined responsibilities. This makes it easier to manage and understand each components role.
   - **Clear Layering:** Separating the `data`, `domain`, and `presentation` layers within each feature promotes adherence to the Clean Architecture principles, facilitating easier maintenance and updates.

2. **Scalability:**
   - **Modularity:** Each feature is self-contained, which means new features can be added with minimal impact on existing code. This modularity supports scalability as the project grows.
   - **Reusability:** Common utilities and widgets are placed in the `shared` directory, allowing for code reuse and reducing duplication.

3. **Maintainability:**
   - **Consistency:** A well-defined structure, with separate directories for constants, enums, and error handling, ensures consistency across the codebase. This organization makes it easier for developers to locate and update code.
   - **Dependency Injection:** The `di` (dependency injection) folder centralizes the setup of dependencies, improving the manageability of service and repository instances.

4. **Flexibility:**
   - **Localization and Assets Management:** The `l10n` and `gen` folders handle localization and asset management, respectively, providing a clear path for adding new languages or updating assets without disrupting the main codebase.

### **Brief Explanation of the Structure**

- **`src/app`**: Contains the entry point of the application (`app.dart`) and routing configuration (`app_router.dart`). It sets up the main app configuration and navigation.
  
- **`src/core`**: Holds fundamental aspects of the application such as constants, enums, error handling, and network configuration. It includes helpers and utilities used throughout the app, as well as theme definitions.

- **`src/di`**: Manages dependency injection, with various locators for different types of dependencies. This setup ensures that services, data sources, and repositories are instantiated and provided where needed.

- **`src/features`**: Organized by feature with subdirectories for `data`, `domain`, and `presentation` layers:
  - **`data`**: Contains data sources, models, and repository implementations.
  - **`domain`**: Defines entities, abstract repositories, and use cases.
  - **`presentation`**: Manages state (e.g., `bloc`), UI pages, and widgets.

- **`src/l10n`**: Manages localization files and configuration, enabling support for multiple languages.

- **`src/shared`**: Includes common widgets and wrappers that are used across different features of the application.

- **`bootstrap.dart`**: Contains initialization logic, likely setting up the environment before the application starts.

- **Entry Points (`main_development.dart`, `main_staging.dart`, `main_production.dart`)**: Separate entry points for different environments, allowing for environment-specific configurations and testing.

Overall, this structure promotes a clean, modular, and maintainable codebase, making it easier to manage complex Flutter projects as they evolve.

---

### Why We Chose to Use Either for Handling Errors
Either is a powerful functional programming construct used to handle errors and manage multiple possible outcomes in a clean and type-safe manner. It represents a value that can either be a Right (successful result) or a Left (an error).

Why Either Helps
Error Handling: Using Either allows for explicit error handling without relying on exceptions. This makes error management more predictable and easier to reason about.
Functional Programming Paradigm: It fits well with functional programming principles, which align with Clean Architecture’s emphasis on separating concerns and handling errors in a functional style.
Type Safety: Either ensures that error handling and success cases are type-checked at compile time, reducing the risk of runtime errors.
Example Usage
```dart
import 'package:dartz/dartz.dart';

class UserRepository {
  Future<Either<Failure, User>> getUser(String id) async {
    try {
      final response = await apiService.getUser(id);
      return Right(response);
    } catch (e) {
      return Left(Failure(e.toString()));
    }
  }
}
```
In this example, Either is used to return either a Right containing a successful User object or a Left containing a Failure object. This approach ensures that error handling is explicit and manageable.

### Using Retrofit for API Integration

Retrofit simplifies the process of API integration in my project by providing a type-safe, declarative way to define API endpoints. Instead of manually writing HTTP requests, We define the endpoints as abstract methods, and Retrofit generates the implementation.

#### Example Usage:

```dart
import 'package:retrofit/retrofit.dart';
import 'package:dio/dio.dart';

part 'api_service.g.dart';

@RestApi(baseUrl: "https://api.example.com")
abstract class ApiService {
  factory ApiService(Dio dio, {String baseUrl}) = _ApiService;

  @GET("/users/{id}")
  Future<User> getUser(@Path("id") String id);
}
```

With Retrofit, We can define the API endpoints as abstract methods. The generated code handles the actual HTTP requests, making the API integration process more straightforward and less error-prone.

### JSON Serializer and Freezed for Model Generation

For model generation, We will use JSON Serializer and Freezed. These tools help automate the creation of immutable classes and ensure type safety as well as object equality.

- **JSON Serializer**: Automatically handles the conversion between JSON data and Dart objects, reducing boilerplate code and potential errors.
  
- **Freezed**: Generates union types and immutable classes, which are essential for maintaining consistent and reliable data structures throughout the project.

#### Example:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
class User with _$User {
  factory User({
    required String id,
    required String name,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
```

With `Freezed` and `JSON Serializer`, We ensure that the models are immutable and that serialization is handled seamlessly, improving the overall reliability of the data layer.

### Using AutoRouter for Navigation

AutoRouter streamlines navigation within the project by generating route definitions and handling complex navigation logic automatically. This eliminates the need to manually define routes, making the navigation system more scalable and easier to manage.

#### Example Configuration:

```dart
import 'package:auto_route/auto_route.dart';

@MaterialAutoRouter(
  routes: <AutoRoute>[
    AutoRoute(page: HomePage, initial: true),
    AutoRoute(page: ProfilePage),
    AutoRoute(page: SettingsPage),
  ],
)
class $AppRouter {}
```

In this example, AutoRouter generates the necessary routing logic based on the annotated routes. This approach reduces the likelihood of navigation errors and makes it easier to manage routes as the project evolves.

---

By choosing Clean Architecture and integrating tools like Flutter Hooks, Retrofit, JSON Serializer, Freezed, and AutoRouter, We have built a solid foundation for the project. This setup ensures that the code is clean, maintainable, and scalable, making it easier to develop and extend the project over time.