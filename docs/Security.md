# Security Documentation

## 1. **Environment Configuration (ENV)**
Each environment in the project—development, staging, and production—uses its own `.env` file to securely manage sensitive configurations such as API keys, secrets, and endpoints. This ensures that no hardcoded sensitive information is present within the codebase, reducing the risk of leaks during development or staging.

- **Development Environment (`.env.development`)**: Contains variables for development services.
- **Staging Environment (`.env.staging`)**: Configures variables for testing environments.
- **Production Environment (`.env.production`)**: Stores variables strictly for production.

All `.env` files are excluded from version control by including them in the `.gitignore` file to prevent accidental exposure.

## 2. **Latest Packages and Plugins**
To maintain a high level of security, always use the **latest stable versions** of Flutter SDK, dependencies, and third-party plugins. Keeping everything up to date ensures the project benefits from security patches and bug fixes.

In the project:
- Regularly check and update packages using `flutter pub outdated` to identify deprecated or vulnerable packages.
- Audit dependencies to ensure no insecure or vulnerable versions are being used.

## 3. **Flutter Version**
The project strictly uses the **latest stable Flutter version** to leverage the latest security features and fixes. Regular updates to the Flutter SDK reduce the risk of exploiting known vulnerabilities.

- A version constraint is applied in the `pubspec.yaml` to prevent downgrading to a vulnerable Flutter version:

  ```yaml
  environment:
    sdk: ">=3.0.0 <4.0.0"
  ```

## 4. **Data Encryption with Hive**
The project uses the **Hive** database for local storage, which offers **AES-256 encryption** to secure sensitive user data such as tokens, preferences, or credentials. This is a more secure alternative to `SharedPreferences`, which does not offer encryption by default.

The `LocalStorageServiceImpl` class serves as a centralized service for storing and managing data locally. It leverages **Hive**, ensuring that all locally stored data is protected with **AES-256 encryption**.

### Key Features of `LocalStorageServiceImpl`:
1. **Initialization (`initDB`)**: Opens a Hive box (`card_box_0`) for securely storing key-value pairs. The data in this box is encrypted with AES-256 to ensure protection.
   
2. **Save Data (`savePreference`)**: Stores a key-value pair in the Hive box, providing efficient and secure local storage.

3. **Retrieve Data (`getPreference`)**: Retrieves a value based on the provided key, ensuring that data is securely accessed when needed.

4. **Delete Data (`deletePreference`)**: Safely deletes a key-value pair from the Hive box and logs any errors during the process using the **Logger** package.

### Emphasizing the Use of Hive:
- **Secure Data Storage**: Hive provides built-in AES-256 encryption, making it a preferred choice over `SharedPreferences` for storing sensitive data.
  
- **Performance**: Hive is optimized for Flutter applications, ensuring high performance when reading, writing, or deleting data even with large datasets.

### Example Usage of `LocalStorageService`:

```dart
final localStorage = locator<LocalStorageService>();

// Save a preference
await localStorage.savePreference(key: 'user_token', data: 'abc123');

// Retrieve the saved preference
final token = localStorage.getPreference(key: 'user_token');

// Delete the preference
await localStorage.deletePreference(key: 'user_token');
```

By using `LocalStorageServiceImpl`, the project benefits from Hive's high performance and secure encryption, ensuring that local data storage is handled efficiently and safely.

## 5. **Secure HTTP Communications**
The project enforces **HTTPS** for all network requests to ensure encrypted communication between the app and backend services. Additionally, SSL pinning can be implemented to protect against man-in-the-middle (MITM) attacks.

- Use the latest version of the **Dio** or **Retrofit** library for API communication, as they offer advanced security mechanisms, including request interceptors for added control.

## 6. **Obfuscation**
Obfuscation is enabled for the project in release mode to prevent reverse engineering and protect the code from tampering.

- Obfuscate Dart code by enabling it in `build.gradle` for Android or Xcode settings for iOS:
  
  ```yaml
  android {
    buildTypes {
      release {
        minifyEnabled true
        shrinkResources true
        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
      }
    }
  }
  ```

  For iOS, obfuscation can be enabled by adding flags in the Xcode build settings to strip unnecessary symbols.

## 7. **Authentication and Token Management**
- Use **OAuth2.0** or **JWT (JSON Web Tokens)** for managing user authentication securely.
- Tokens are encrypted and stored locally using Hive to ensure they cannot be easily accessed or manipulated.
- Implement **token expiration and renewal** mechanisms to prevent session hijacking.

## 8. **Secure API Usage**
- Ensure that all API endpoints are authenticated and properly authorized. Only the minimum required permissions should be granted to each API client.
- **Rate-limiting** can be implemented to prevent brute-force attacks.

## 9. **Input Validation and Sanitization**
All user input is validated and sanitized to prevent injection attacks such as **SQL Injection** or **Cross-Site Scripting (XSS)**. Ensure that forms, search inputs, and any user-generated content are properly validated on both the client and server side.

## 10. **App Permissions**
- Only request **minimal permissions** required by the app. This reduces the attack surface by limiting access to sensitive data like location, contacts, or the camera.
- Ensure that permissions are requested at runtime and justified to the user.

## 11. **Secure Coding Practices**
- Ensure that sensitive information, such as API keys and tokens, is stored securely and never logged.
- Use **FlutterSecureStorage** for secure storage of credentials or use Hive with AES-256 encryption for data-at-rest.
- Always handle exceptions and errors securely. Avoid exposing sensitive data in error messages or logs.

## 12. **Third-Party Library Audits**
Regularly audit third-party libraries used in the project. Tools such as **Snyk** or **Dependabot** can be integrated into the CI/CD pipeline to automatically scan for vulnerabilities in dependencies.

## 13. **CI/CD Security**
The CI/CD pipelines (hosted in GitHub Actions) are configured securely:
- **Secrets**: Sensitive environment variables and credentials are stored in encrypted GitHub Secrets and never exposed in logs.
- **Action Pinning**: All external GitHub Actions are pinned to specific SHA-1 hashes to avoid pulling in malicious updates.

By adhering to these security practices, the project ensures the highest standards of data protection and code integrity across all environments.
