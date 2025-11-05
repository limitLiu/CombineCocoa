#if canImport(Combine)

import Combine
import Foundation

extension Publisher {
  public func concatMap<T: Publisher>(_ transform: @escaping (Output) -> T) -> Publishers.ConcatMap<Self, T> {
    .init(upstream: self, transform: transform)
  }
}

extension Publishers {
  public struct ConcatMap<Upstream: Publisher, Downstream: Publisher>: Publisher
  where Upstream.Failure == Downstream.Failure {
    public typealias Output = Downstream.Output
    public typealias Failure = Upstream.Failure

    private let upstream: Upstream
    private let transform: (Upstream.Output) -> Downstream

    public init(upstream: Upstream, transform: @escaping (Upstream.Output) -> Downstream) {
      self.upstream = upstream
      self.transform = transform
    }

    public func receive<S: Subscriber>(subscriber: S)
    where S.Input == Output, S.Failure == Failure {
      let subscription = ConcatMapSubscription(
        upstream: upstream,
        downstream: subscriber,
        transform: transform
      )
      subscriber.receive(subscription: subscription)
    }
  }
}

private final class ConcatMapSubscription<Upstream: Publisher, Downstream: Publisher, FinalDownstream: Subscriber>:
  Subscription, Subscriber
where
  FinalDownstream.Input == Downstream.Output,
  FinalDownstream.Failure == Upstream.Failure,
  Upstream.Failure == Downstream.Failure
{
  typealias Input = Upstream.Output
  typealias Failure = Upstream.Failure

  private let downstream: FinalDownstream
  private let transform: (Upstream.Output) -> Downstream

  private let lock = NSRecursiveLock()

  private var upstreamQueue: [Upstream.Output] = []
  private var isProcessing: Bool = false
  private var downstreamDemand: Subscribers.Demand = .none
  private var upstreamSubscription: Subscription?
  private var innerSubscription: Subscription?
  private var isUpstreamFinished: Bool = false

  init(
    upstream: Upstream,
    downstream: FinalDownstream,
    transform: @escaping (Upstream.Output) -> Downstream
  ) {
    self.downstream = downstream
    self.transform = transform
    upstream.subscribe(self)
  }

  func request(_ demand: Subscribers.Demand) {
    lock.lock()
    downstreamDemand += demand
    let subscription = self.innerSubscription ?? self.upstreamSubscription
    lock.unlock()
    subscription?.request(demand)
  }

  func cancel() {
    lock.lock()
    upstreamQueue.removeAll()
    let upstream = self.upstreamSubscription
    let inner = self.innerSubscription
    self.upstreamSubscription = nil
    self.innerSubscription = nil
    lock.unlock()
    upstream?.cancel()
    inner?.cancel()
  }

  func receive(subscription: Subscription) {
    lock.lock()
    self.upstreamSubscription = subscription
    lock.unlock()
    subscription.request(.max(1))
  }

  func receive(_ input: Upstream.Output) -> Subscribers.Demand {
    lock.lock()
    if isProcessing {
      upstreamQueue.append(input)
    } else {
      isProcessing = true
      startProcessing(element: input)
    }
    lock.unlock()
    return .none
  }

  func receive(completion: Subscribers.Completion<Upstream.Failure>) {
    lock.lock()
    isUpstreamFinished = true
    if !isProcessing && upstreamQueue.isEmpty {
      lock.unlock()
      downstream.receive(completion: completion)
    } else {
      lock.unlock()
    }
  }

  private func startProcessing(element: Upstream.Output) {
    let innerPublisher = transform(element)

    let innerSubscriber = InnerSubscriber(parent: self)
    innerPublisher.subscribe(innerSubscriber)
  }

  fileprivate func innerDidComplete(with completion: Subscribers.Completion<Downstream.Failure>?) {
    lock.lock()
    innerSubscription = .none
    if case .failure(let error) = completion {
      lock.unlock()
      downstream.receive(completion: .failure(error))
      return
    }

    if !upstreamQueue.isEmpty {
      let nextElement = upstreamQueue.removeFirst()
      lock.unlock()
      startProcessing(element: nextElement)
    } else {
      isProcessing = false
      if isUpstreamFinished {
        lock.unlock()
        downstream.receive(completion: .finished)
      } else {
        let subscription = self.upstreamSubscription
        lock.unlock()
        subscription?.request(.max(1))
      }
    }
  }

  fileprivate func received(innerSubscription: Subscription) {
    lock.lock()
    self.innerSubscription = innerSubscription
    let demand = self.downstreamDemand
    lock.unlock()
    if demand > .none {
      innerSubscription.request(demand)
    }
  }
}

private extension ConcatMapSubscription {
  class InnerSubscriber: Subscriber {
    typealias Input = Downstream.Output
    typealias Failure = Downstream.Failure

    private weak var parent: ConcatMapSubscription?

    init(parent: ConcatMapSubscription) {
      self.parent = parent
    }

    func receive(subscription: Subscription) {
      parent?.received(innerSubscription: subscription)
    }

    func receive(_ input: Downstream.Output) -> Subscribers.Demand {
      return parent?.downstream.receive(input) ?? .none
    }

    func receive(completion: Subscribers.Completion<Downstream.Failure>) {
      parent?.innerDidComplete(with: completion)
    }
  }
}

#endif
