#if canImport(Combine)

import Combine
import Foundation

public protocol ControlEventType: Publisher {
  func asControlEvent() -> ControlEvent<Output>
}

public struct ControlEvent<PropertyType>: ControlEventType {
  public typealias Output = PropertyType
  public typealias Failure = Never
  public typealias Element = PropertyType

  let events: Observable<PropertyType>

  public init<Ev: Publisher>(events: Ev) where Ev.Output == Element, Ev.Failure == Never {
    self.events = events.receive(on: RunLoop.main).eraseToAnyPublisher()
  }

  public func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, PropertyType == S.Input {
    self.events.receive(subscriber: subscriber)
  }

  public func asObservable() -> Observable<Element> {
    self.events
  }

  public func asControlEvent() -> ControlEvent<Element> {
    self
  }
}

#endif
