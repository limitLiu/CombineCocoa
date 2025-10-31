#if canImport(Combine)

import Combine

extension ObservableConvertibleType {
  public func asDriver(onErrorJustReturn: Element) -> Driver<Element> {
    let source = self
      .asObservable()
      .receive(on: DriverSharingStrategy.scheduler)
      .catch({ _ in
        Just(onErrorJustReturn)
      })
      .eraseToAnyPublisher()
    return Driver(source)
  }
  
  public func asDriver(onErrorDriveWith: Driver<Element>) -> Driver<Element> {
    let source = self
      .asObservable()
      .receive(on: DriverSharingStrategy.scheduler)
      .catch { _ in
        onErrorDriveWith.asObservable()
      }
      .eraseToAnyPublisher()
    return Driver(source)
  }
  
  public func asDriver(onErrorRecover: @escaping (_ error: Swift.Error) -> Driver<Element>) -> Driver<Element> {
    let source = self
      .asObservable()
      .receive(on: DriverSharingStrategy.scheduler)
      .catch { error in
        onErrorRecover(error).asObservable()
      }
      .eraseToAnyPublisher()
    return Driver(source)
  }
}

#endif
