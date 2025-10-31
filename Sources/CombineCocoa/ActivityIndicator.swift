import Combine
import Foundation

public class ActivityIndicator: SharedSequenceConvertibleType {
  public typealias Element = Bool
  public typealias SharingStrategy = DriverSharingStrategy

  private let _lock = NSRecursiveLock()
  private let _relay = BehaviorRelay(0)
  private let _loading: SharedSequence<SharingStrategy, Bool>

  public init() {
    self._loading = _relay.asDriver()
      .map { $0 > 0 }
      .removeDuplicates()
  }

  fileprivate func trackActivityOfObservable<Source: ObservableConvertibleType>(
    _ source: Source
  ) -> Observable<Source.Element> {
    source.asObservable().handleEvents(
      receiveSubscription: { [weak self] _ in
        self?.increment()
      },
      receiveCompletion: { [weak self] _ in
        self?.decrement()
      },
      receiveCancel: { [weak self] in
        self?.decrement()
      }
    ).eraseToAnyPublisher()
  }

  private func increment() {
    _lock.lock()
    _relay.send(_relay.value + 1)
    _lock.unlock()
  }

  private func decrement() {
    _lock.lock()
    _relay.send(_relay.value - 1)
    _lock.unlock()
  }

  public func asSharedSequence() -> SharedSequence<SharingStrategy, Element> {
    _loading
  }
}

public extension ObservableConvertibleType {
  func trackActivity(_ activityIndicator: ActivityIndicator) -> Observable<Element> {
    activityIndicator.trackActivityOfObservable(self)
  }
}

public extension ActivityIndicator {
  @MainActor
  func track<T, E>(work: @escaping () async throws(E) -> T) async throws(E) -> T {
    increment()
    defer { decrement() }
    return try await work()
  }
}
