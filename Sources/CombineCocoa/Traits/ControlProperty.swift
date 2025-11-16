#if canImport(UIKit)
import Combine
import UIKit.UIControl

public protocol ControlPropertyType: Publisher, ObserverType {
  func asControlProperty() -> ControlProperty<Element>
}

extension ControlPropertyType where Element == String? {
  public var orEmpty: ControlProperty<String> {
    let original: ControlProperty<String?> = asControlProperty()
    let values: Observable<String> = original.values.map { $0 ?? "" }.eraseToAnyPublisher()
    let valueSink: AnyObserver<String> = original.valueSink.mapObserver { $0 }
    return ControlProperty<String>(values: values, valueSink: valueSink)
  }
}

public struct ControlProperty<Value>: @preconcurrency ControlPropertyType {
  public typealias Output = Value
  public typealias Failure = Never
  
  let values: Observable<Value>
  let valueSink: AnyObserver<Value>
  
  public init<Values: Publisher, Sink: ObserverType>(values: Values, valueSink: Sink) where Output == Values.Output, Failure == Values.Failure, Output == Sink.Element {
    self.values = values.receive(on: RunLoop.main).eraseToAnyPublisher()
    self.valueSink = valueSink.asObserver()
  }
  
  @MainActor
  public func receive<S: Subscriber>(subscriber: S) where S.Failure == Never, S.Input == Element {
    values.receive(subscriber: subscriber)
  }
  
  public func on(_ event: Event<Value>) {
    valueSink.on(event)
  }
  
  public func asObservable() -> Observable<Value> {
    values
  }
  
  public func asControlProperty() -> ControlProperty<Value> {
    self
  }
  
  public var changed: AnyPublisher<Value, Failure> {
    values.dropFirst().eraseToAnyPublisher()
  }
}

#endif
