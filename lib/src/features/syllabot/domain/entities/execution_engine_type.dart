/// Execution engines available for Syllabot AI.
enum ExecutionEngineType {
  cloudRemote,
  localOnDevice,
}

extension ExecutionEngineTypeX on ExecutionEngineType {
  String get nameString {
    switch (this) {
      case ExecutionEngineType.cloudRemote:
        return 'cloudRemote';
      case ExecutionEngineType.localOnDevice:
        return 'localOnDevice';
    }
  }

  static ExecutionEngineType fromString(String value) {
    if (value == 'localOnDevice') {
      return ExecutionEngineType.localOnDevice;
    }
    return ExecutionEngineType.cloudRemote;
  }
}
