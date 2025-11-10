#if canImport(Combine)
import Combine

public protocol SharingStrategyProtocol {
  associatedtype SchedulerType: Scheduler
  static var scheduler: SchedulerType { get }
  static func share<Element>(_ source: Observable<Element>) -> Observable<Element>
}

public protocol SharedSequenceConvertibleType: ObservableConvertibleType {
  associatedtype SharingStrategy: SharingStrategyProtocol
  func asSharedSequence() -> SharedSequence<SharingStrategy, Element>
}

extension SharedSequenceConvertibleType {
  public func asObservable() -> Observable<Element> {
    self.asSharedSequence().asObservable()
  }

  public func map<R>(_ transform: @escaping (Element) -> R) -> SharedSequence<SharingStrategy, R> {
    let src = asObservable().map(transform).eraseToAnyPublisher()
    return SharedSequence<SharingStrategy, R>(src)
  }
}

extension SharedSequenceConvertibleType where Element: Equatable {
  public func removeDuplicates() -> SharedSequence<SharingStrategy, Element> {
    let src = asObservable().removeDuplicates { a, b in a == b }.eraseToAnyPublisher()
    return SharedSequence(src)
  }
}

public struct SharedSequence<SharingStrategy: SharingStrategyProtocol, Element>: SharedSequenceConvertibleType,
  ObservableConvertibleType
{
  let source: Observable<Element>

  init(_ source: Observable<Element>) {
    self.source = SharingStrategy.share(source)
  }

  init(raw: Observable<Element>) {
    source = raw
  }

  public func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, Element == S.Input {
    source.receive(subscriber: subscriber)
  }

  public func asObservable() -> Observable<Element> {
    source
  }

  public func asSharedSequence() -> SharedSequence<SharingStrategy, Element> {
    self
  }
}

public extension SharedSequence where SharingStrategy == DriverSharingStrategy {
  @MainActor
  func drive<Observer: ObserverType>(_ observers: Observer...) -> AnyCancellable
  where Observer.Element == Element {
    asSharedSequence().asObservable().sink { e in observers.forEach { $0.on(.next(e)) } }
  }
}

#endif
