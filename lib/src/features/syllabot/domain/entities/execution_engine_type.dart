/// Execution engines available for Syllabot AI.
enum ExecutionEngineType {
  cloudSupabase,
  localOnDevice,
}

extension ExecutionEngineTypeX on ExecutionEngineType {
  String get nameString {
    switch (this) {
      case ExecutionEngineType.cloudSupabase:
        return 'cloudSupabase';
      case ExecutionEngineType.localOnDevice:
        return 'localOnDevice';
    }
  }

  static ExecutionEngineType fromString(String value) {
    if (value == 'localOnDevice') {
      return ExecutionEngineType.localOnDevice;
    }
    return ExecutionEngineType.cloudSupabase;
  }
}
