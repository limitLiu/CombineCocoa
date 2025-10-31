import Combine

public struct AnyObserver<Element>: ObserverType {
  public typealias EventHandler = (Event<Element>) -> Void

  private let observer: EventHandler

  public init(eventHandler: @escaping EventHandler) {
    self.observer = eventHandler
  }

  public init<Observer: ObserverType>(_ observer: Observer) where Observer.Element == Element {
    self.observer = observer.on
  }

  public func on(_ event: Event<Element>) {
    self.observer(event)
  }

  public func asObserver() -> AnyObserver<Element> {
    self
  }
}
