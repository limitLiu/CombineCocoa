func exFatalError(
  _ lastMessage: @autoclosure () -> String,
  file: StaticString = #file,
  line: UInt = #line
) -> Swift.Never {
  fatalError(lastMessage(), file: file, line: line)
}

func exFatalError(_ lastMessage: String) -> Never {
  fatalError(lastMessage)
}

func exAbstractMethod(file: StaticString = #file, line: UInt = #line) -> Swift.Never {
  exFatalError("Abstract method", file: file, line: line)
}

func exAbstractMethod(
  message: String = "Abstract method",
  file: StaticString = #file,
  line: UInt = #line
) -> Swift.Never {
  exFatalError(message, file: file, line: line)
}

func exFatalErrorInDebug(_ lastMessage: @autoclosure () -> String, file: StaticString = #file, line: UInt = #line) {
  #if DEBUG
  fatalError(lastMessage(), file: file, line: line)
  #else
  print("\(file):\(line): \(lastMessage())")
  #endif
}

func castOrThrow<T>(_ resultType: T.Type, _ object: Any) throws -> T {
  guard let r = object as? T else {
    throw ExCocoaError.castingError(object: object, targetType: resultType)
  }
  return r
}

@MainActor
public enum ExCocoaError: Swift.Error, @MainActor CustomDebugStringConvertible {
  case unknown
  case invalidOperation(object: Any)
  case itemsNotYetBound(object: Any)
  case invalidPropertyName(object: Any, propertyName: String)
  case invalidObjectOnKeyPath(object: Any, sourceObject: AnyObject, propertyName: String)
  case errorDuringSwizzling
  case castingError(object: Any, targetType: Any.Type)
}

extension ExCocoaError {
  public var debugDescription: String {
    switch self {
    case .unknown:
      "Unknown error occurred."
    case let .invalidOperation(object):
      "Invalid operation was attempted on `\(object)`."
    case let .itemsNotYetBound(object):
      "Data source is set, but items are not yet bound to user interface for `\(object)`."
    case let .invalidPropertyName(object, propertyName):
      "Object `\(object)` doesn't have a property named `\(propertyName)`."
    case let .invalidObjectOnKeyPath(object, sourceObject, propertyName):
      "Unobservable object `\(object)` was observed as `\(propertyName)` of `\(sourceObject)`."
    case .errorDuringSwizzling:
      "Error during swizzling."
    case let .castingError(object, targetType):
      "Error casting `\(object)` to `\(targetType)`"
    }
  }
}

extension ExCocoaError {
  var isItemsNotYetBound: Bool {
    switch self {
    case .itemsNotYetBound(object: _): true
    default: false
    }
  }
}

func bindingError(_ error: Swift.Error) {
  let error = "Binding error: \(error)"
  #if DEBUG
  exFatalError(error)
  #else
  print(error)
  #endif
}
