#if canImport(Combine)
import Combine

public protocol ObserverType {
  associatedtype Element
  func on(_ event: Event<Element>)
}

extension ObserverType {
  public func asObserver() -> AnyObserver<Element> {
    AnyObserver(self)
  }

  public func mapObserver<R>(_ transform: @escaping (R) throws -> Element) -> AnyObserver<R> {
    AnyObserver { e in
      self.on(e.map(transform))
    }
  }
}

#endif
