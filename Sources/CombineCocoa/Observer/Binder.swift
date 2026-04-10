#if canImport(Combine)

import Combine
import Foundation

public struct Binder<Value>: ObserverType {
  public typealias Element = Value

  private let binding: (Event<Value>) -> Void

  public init<Target: AnyObject>(
    _ target: Target,
    scheduler: any Scheduler = MainScheduler.instance,
    binding: @escaping (Target, Value) -> Void,
  ) {
    weak let weakTarget = target
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
    AnyObserver(eventHandler: on(_:))
  }
}

public extension Combine.Publisher where Failure == Never {
  func bind<Observer: ObserverType>(to observers: Observer...) -> AnyCancellable
    where Observer.Element == Output {
    sink { event in
      observers.forEach { $0.on(.next(event)) }
    }
  }

  func bind<Observer: ObserverType>(to binders: Observer...) -> AnyCancellable
    where Observer.Element == Output? {
    map { $0 as Output? }
      .sink { event in
        binders.forEach { $0.on(.next(event)) }
      }
  }

  func bind<R>(to binder: (Self) -> R) -> R {
    binder(self)
  }
}

public extension Combine.Publisher {
  func bind<Observer: ObserverType>(to observers: Observer...) -> AnyCancellable
    where Observer.Element == Output {
    sink(
      receiveCompletion: { completion in
        if case let .failure(err) = completion {
          observers.forEach { $0.on(.error(err)) }
        }
      },
      receiveValue: { value in
        observers.forEach { $0.on(.next(value)) }
      },
    )
  }

  func bind<Observer: ObserverType>(to observers: Observer...) -> AnyCancellable
    where Observer.Element == Output? {
    map { $0 as Output? }
      .sink(
        receiveCompletion: { completion in
          if case let .failure(err) = completion {
            observers.forEach { $0.on(.error(err)) }
          }
        },
        receiveValue: { value in
          observers.forEach { $0.on(.next(value)) }
        },
      )
  }
}

public extension Publisher {
  func bind<R1, R2>(to binder: (Self) -> (R1) -> R2, curriedArgument: R1) -> R2 {
    binder(self)(curriedArgument)
  }
}

#endif
