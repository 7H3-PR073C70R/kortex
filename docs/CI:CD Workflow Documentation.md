## CI/CD Workflow Documentation

### Overview

This project automates the build, testing, and distribution processes using **GitHub Actions** for both Android and iOS platforms. The workflow handles building the app based on the environment (development, staging, production), ensuring it is ready for release at any time. Additionally, the workflow includes testing and linting steps to ensure code quality and standards are maintained. **Firebase App Distribution** is used as the primary distribution platform for both Android and iOS apps, facilitating easy and secure internal testing.

### Workflow Structure

The CI/CD pipeline is split into multiple key workflows:
- **Build for Android**: Automates building the Android APK and distributes it via Firebase App Distribution.
- **Build for iOS**: Automates building the iOS IPA and distributes it via Firebase App Distribution.
- **Test Code and Lint**: Verifies that the code passes linting rules, unit tests, and spelling checks.
- **Trigger Workflows for Development, Staging, and Production**: Ensures that environment-specific workflows are triggered for both Android and iOS builds.

#### Secrets and Security Considerations

Sensitive data, such as API keys, certificates, and passwords, is stored securely in GitHub’s **Secrets** management system. These secrets are essential for securely handling the build and deployment process. By utilizing secrets like `firebase_token`, `android_keystore_base64`, and `certificate_p12`, the project maintains security while also automating the workflows without exposing sensitive data.

### Firebase for App Distribution

#### Why Firebase App Distribution?

**Firebase App Distribution** is used in the workflows for securely distributing APKs and IPAs to testers. Firebase allows internal testers to easily access different builds (development, staging, production) via the Firebase console or the Firebase App Tester app. This approach offers several key benefits:

1. **Simple App Access**: Testers can access the latest builds via Firebase without the need for complex installation processes. It streamlines the testing phase, allowing testers to quickly install and start testing the new builds.
   
2. **Build Management**: Firebase automatically keeps track of all distributed builds, making it easy to manage multiple versions of the app across different environments. This also helps with feedback tracking and debugging.

3. **Cross-Platform Support**: Firebase supports both Android and iOS, which aligns perfectly with the project's need to distribute apps for both platforms.

4. **Automated Notifications**: Testers receive automated email notifications when new builds are uploaded, ensuring they are always testing the latest version.

#### Firebase Integration in Workflows

Firebase is integrated into the GitHub Actions workflows as the primary distribution platform for both Android and iOS builds. After each successful build, the APK or IPA is automatically uploaded to Firebase for distribution to testers.

##### Android Build Workflow

1. **Set up Firebase**: The `firebase_token` secret is used to authenticate with Firebase App Distribution.
2. **Build APK**: The Android APK is built for the specified environment.
3. **Upload to Firebase**: The APK is automatically uploaded to Firebase App Distribution, using the `firebase_android_app_id` to identify the app.
4. **Notify Testers**: Firebase automatically sends notifications to testers about the new build.

##### iOS Build Workflow

1. **Set up Firebase**: Like the Android workflow, the `firebase_token` secret is used to authenticate with Firebase App Distribution.
2. **Build IPA**: The iOS IPA is built, signed, and prepared for distribution.
3. **Upload to Firebase**: The IPA is uploaded to Firebase App Distribution, using the `firebase_ios_app_id` to identify the app.
4. **Notify Testers**: Testers receive notifications via Firebase about the new iOS build.

### Test Code and Lint Workflow

This workflow ensures code quality and helps maintain consistent standards across the codebase. It runs on every push and pull request, allowing early detection of issues.

Key steps include:
1. **Check for Semantic PR**: Ensures that all pull requests adhere to semantic commit guidelines.
2. **Run Linting**: Executes `flutter analyze` to catch code style violations and enforce best practices.
3. **Run Unit Tests**: The test suite is run using `flutter test`, ensuring that the code functions as expected.
4. **Spelling Check**: Uses the `cspell.json` configuration to check for typos and misspellings in code and documentation.

### Triggers for Development, Staging, and Production Builds

There are separate workflows for triggering builds based on the environment (development, staging, or production). These workflows use the `workflow_dispatch` event to allow manual triggering, and they call the appropriate Android and iOS workflows, passing in the relevant secrets and configurations for the target environment. Firebase is consistently used across all environments to distribute the build to testers.

### Why Use Secrets?

1. **Secure Key Management**: Secrets securely store sensitive information such as Firebase tokens, Android keystore passwords, and iOS certificate credentials. This ensures that credentials are not exposed in the source code.
   
2. **Ease of Maintenance**: Secrets allow you to update or rotate keys without modifying the source code, making it easier to manage and secure credentials across multiple environments.
   
3. **Environment-Specific Configurations**: Different environments (development, staging, production) may require unique secrets, such as separate Firebase App IDs for Android and iOS. The secrets management system ensures that the correct credentials are used for each environment.

### Conclusion

This CI/CD pipeline is designed to ensure continuous delivery with maximum security and flexibility. By leveraging **Firebase App Distribution**, the workflow simplifies the process of distributing builds to testers, making it easy to manage feedback and iterate quickly. Automated linting, testing, and spelling checks further enhance code quality, helping maintain a high standard throughout the project lifecycle.