#if canImport(Combine)

@frozen public enum Event<Element> {
  case next(Element)
  case error(Swift.Error)
  case completed
}

extension Event {
  public func map<R>(_ transform: (Element) throws -> R) -> Event<R> {
    do {
      return switch self {
      case let .next(element): .next(try transform(element))
      case let .error(error): .error(error)
      case .completed: .completed
      }
    } catch {
      return .error(error)
    }
  }
}

#endif
