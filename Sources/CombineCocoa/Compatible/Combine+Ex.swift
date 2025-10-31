import Combine
import Foundation

extension CurrentValueSubject: ObserverType where Failure == Never {
  public typealias Element = Output
  
  public func on(_ event: Event<Output>) {
    switch event {
    case let .next(value):
      send(value)
    case .error, .completed:
      send(completion: .finished)
      break
    }
  }
  
  public func asDriver() -> Driver<Element> {
    let source = self.receive(on: DriverSharingStrategy.scheduler).eraseToAnyPublisher()
    return SharedSequence(source)
  }
}

extension PassthroughSubject: ObserverType where Failure == Never {
  public typealias Element = Output
  public func on(_ event: Event<Output>) {
    switch event {
    case .next(let value):
      send(value)
    case .error, .completed:
      send(completion: .finished)
      break
    }
  }
}

extension PublishSubject: ObserverType where Failure == Never {
  public typealias Element = Output
  public func on(_ event: Event<Output>) {
    switch event {
    case .next(let value):
      send(value)
    case .error, .completed:
      send(completion: .finished)
      break
    }
  }
  
  public func on(next event: Element) {
    send(event)
  }
}

extension Publishers.Map: ObservableConvertibleType where Failure == Never {
  public typealias Element = Output
  
  public func asObservable() -> Observable<Element> {
    self.eraseToAnyPublisher()
  }
}

extension Publisher where Failure == Error {
  @MainActor
  public static func single<Output>(async work: @escaping @Sendable () async throws -> Output) -> AnyPublisher<Result<Output, Failure>, Never> {
    Future<Result<Output, Failure>, Never> { promise in
      Task {
        do {
          let r = try await work()
          promise(.success(.success(r)))
        } catch {
          promise(.success(.failure(error)))
        }
      }
    }.eraseToAnyPublisher()
  }
}

extension AnyPublisher: ObservableConvertibleType where Failure == Never {
  public typealias Element = Output
  public func asObservable() -> Observable<Element> {
    return self
  }
}

extension Publisher {
  public func withLatest<P: Publisher>(from other: P) -> Publishers.WithLatestFrom<Self, P> where P.Failure == Failure {
    Publishers.WithLatestFrom(upstream: self, other: other)
  }
  
  public func withLatest<P: Publisher>(from other: P) -> AnyPublisher<P.Output, Failure> where P.Failure == Failure {
    Publishers.WithLatestFrom(upstream: self, other: other)
      .map { (_, snd) in snd }
      .eraseToAnyPublisher()
  }

  public func combineLatest<Others: Collection>(with others: Others) -> AnyPublisher<[Output], Failure>
  where Others.Element: Publisher, Others.Element.Output == Output, Others.Element.Failure == Failure {
    ([self.eraseToAnyPublisher()] + others.map { $0.eraseToAnyPublisher() }).combineLatest()
  }
  
  public func combineLatest<Other: Publisher>(with others: Other...)
  -> AnyPublisher<[Output], Failure>
  where Other.Output == Output, Other.Failure == Failure {
    combineLatest(with: others)
  }
}

extension Collection where Element: Publisher {
  public func combineLatest() -> AnyPublisher<[Element.Output], Element.Failure> {
    var wrapped = map { $0.map { [$0] }.eraseToAnyPublisher() }
    while wrapped.count > 1 {
      wrapped = makeCombinedQuads(input: wrapped)
    }
    return wrapped.first?.eraseToAnyPublisher() ?? Empty().eraseToAnyPublisher()
  }
}

private func makeCombinedQuads<Output, Failure: Swift.Error>(
  input: [AnyPublisher<[Output], Failure>]
) -> [AnyPublisher<[Output], Failure>] {
  sequence(
    state: input.makeIterator(),
    next: { it in it.next().map { ($0, it.next(), it.next(), it.next()) } }
  )
  .map { quad in
    guard let second = quad.1 else { return quad.0 }
    guard let third = quad.2 else {
      return quad.0
        .combineLatest(second)
        .map { $0.0 + $0.1 }
        .eraseToAnyPublisher()
    }
    guard let fourth = quad.3 else {
      return quad.0
        .combineLatest(second, third)
        .map { $0.0 + $0.1 + $0.2 }
        .eraseToAnyPublisher()
    }
    return quad.0
      .combineLatest(second, third, fourth)
      .map { $0.0 + $0.1 + $0.2 + $0.3 }
      .eraseToAnyPublisher()
  }
}
