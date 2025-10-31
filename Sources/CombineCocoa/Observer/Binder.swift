#if canImport(Combine)

import Combine
import Foundation

public struct Binder<Value>: ObserverType {
  public typealias Element = Value

  private let binding: (Event<Value>) -> Void

  public init<Target: AnyObject>(
    _ target: Target,
    scheduler: Scheduler = RunLoop.main,
    binding: @escaping (Target, Value) -> Void
  ) {
    weak var weakTarget = target
    self.binding = { event in
      switch event {
      case let .next(value):
        scheduler.schedule {
          if let target = weakTarget {
            binding(target, value)
          }
        }
      case let .error(e):
        exFatalErrorInDebug("Binding error: \(e)")
      case .completed:
        break
      }
    }
  }

  public func on(_ event: Event<Value>) {
    binding(event)
  }

  public func asObserver() -> AnyObserver<Value> {
    AnyObserver(eventHandler: self.on(_:))
  }
}

extension Combine.Publisher where Failure == Never {
  public func bind<Observer: ObserverType>(to observers: Observer...) -> AnyCancellable
  where Observer.Element == Output {
    self.sink { event in
      observers.forEach { $0.on(.next(event)) }
    }
  }

  public func bind<Observer: ObserverType>(to binders: Observer...) -> AnyCancellable
  where Observer.Element == Output? {
    self
      .map { $0 as Output? }
      .sink { event in
        binders.forEach { $0.on(.next(event)) }
      }
  }

  public func bind<R>(to binder: (Self) -> R) -> R {
    binder(self)
  }
}

extension Combine.Publisher {
  public func bind<Observer: ObserverType>(to observers: Observer...) -> AnyCancellable
  where Observer.Element == Output {
    sink(
      receiveCompletion: { completion in
        if case .failure(let err) = completion {
          observers.forEach { $0.on(.error(err)) }
        }
      },
      receiveValue: { value in
        observers.forEach { $0.on(.next(value)) }
      }
    )
  }

  public func bind<Observer: ObserverType>(to observers: Observer...) -> AnyCancellable
  where Observer.Element == Output? {
    self
      .map { $0 as Output? }
      .sink(
        receiveCompletion: { completion in
          if case .failure(let err) = completion {
            observers.forEach { $0.on(.error(err)) }
          }
        },
        receiveValue: { value in
          observers.forEach { $0.on(.next(value)) }
        }
      )
  }
}

extension Publisher {
  public func bind<R1, R2>(to binder: (Self) -> (R1) -> R2, curriedArgument: R1) -> R2 {
    binder(self)(curriedArgument)
  }
}

#endif
