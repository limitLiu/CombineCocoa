#if canImport(Combine)
import Combine
import Foundation

extension Publishers {
  public struct WithLatestFrom<Upstream: Publisher, Other: Publisher>: Publisher
  where Upstream.Failure == Other.Failure {
    public typealias Output = (Upstream.Output, Other.Output)
    public typealias Failure = Upstream.Failure

    private let upstream: Upstream
    private let other: Other

    public init(upstream: Upstream, other: Other) {
      self.upstream = upstream
      self.other = other
    }

    public func receive<S>(subscriber: S)
    where S: Subscriber, Upstream.Failure == S.Failure, (Upstream.Output, Other.Output) == S.Input {
      let inner = Inner(downstream: subscriber, other: other)
      upstream.subscribe(inner)
    }
  }
}

extension Publishers.WithLatestFrom {
  final private class Inner<Downstream: Subscriber>: Subscription, Subscriber
  where Downstream.Input == Output, Downstream.Failure == Upstream.Failure {
    typealias Input = Upstream.Output

    private let downstream: Downstream
    private var otherSubscriptions: AnyCancellable?
    private var latestValueFromOther: Other.Output?
    private let lock = NSRecursiveLock()
    private var downstreamDemand: Subscribers.Demand = .none
    private var upstreamSubscription: Subscription?

    init(downstream: Downstream, other: Other) {
      self.downstream = downstream
      self.otherSubscriptions = other.sink(
        receiveCompletion: { [weak self] completion in
          self?.handleCompletion(completion)
        },
        receiveValue: { [weak self] in
          self?.handleValue($0)
        }
      )
    }

    func receive(subscription: Subscription) {
      lock.lock()
      defer { lock.unlock() }
      guard self.upstreamSubscription == nil else {
        subscription.cancel()
        return
      }
      self.upstreamSubscription = subscription
      downstream.receive(subscription: self)
    }

    func receive(_ input: Input) -> Subscribers.Demand {
      lock.lock()
      defer { lock.unlock() }
      guard let latest = latestValueFromOther else {
        return .none
      }
      guard downstreamDemand > 0 else {
        return .none
      }
      downstreamDemand -= 1
      let demand = downstream.receive((input, latest))
      downstreamDemand += demand
      return .none
    }

    func receive(completion: Subscribers.Completion<Failure>) {
      handleCompletion(completion)
    }

    func request(_ demand: Subscribers.Demand) {
      lock.lock()
      defer { lock.unlock() }
      downstreamDemand += demand
      upstreamSubscription?.request(demand)
    }

    func cancel() {
      upstreamSubscription?.cancel()
      otherSubscriptions?.cancel()
      upstreamSubscription = .none
      otherSubscriptions = .none
    }

    private func handleCompletion(_ completion: Subscribers.Completion<Failure>) {
      lock.lock()
      defer { lock.unlock() }
      guard otherSubscriptions != .none else { return }
      cancel()
      downstream.receive(completion: completion)
    }

    private func handleValue(_ value: Other.Output) {
      lock.lock()
      defer { lock.unlock() }
      latestValueFromOther = value
    }
  }
}

#endif
