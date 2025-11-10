#if canImport(Combine)

import Combine

extension Publisher {
  public func asDriver(onErrorJustReturn: Output) -> Driver<Output> {
    let source =
      self
      .catch { _ in Just(onErrorJustReturn) }
      .receive(on: DriverSharingStrategy.scheduler)
      .eraseToAnyPublisher()
    return Driver(source)
  }

  public func asDriver(onErrorDriveWith: Driver<Output>) -> Driver<Output> {
    let source =
      self
      .catch { _ in onErrorDriveWith.asObservable() }
      .receive(on: DriverSharingStrategy.scheduler)
      .eraseToAnyPublisher()
    return Driver(source)
  }

  public func asDriver(onErrorRecover: @escaping (_ error: Swift.Error) -> Driver<Output>) -> Driver<Output> {
    let source =
      self
      .catch { error in onErrorRecover(error).asObservable() }
      .receive(on: DriverSharingStrategy.scheduler)
      .eraseToAnyPublisher()
    return Driver(source)
  }
}

#endif
