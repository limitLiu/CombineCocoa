#if canImport(Combine)

import Combine
import Foundation

extension Publisher {
  public func concatMap<T, R>(_ transform: @escaping (Output) -> R) -> Publishers.ConcatMap<R, Self>
  where T == R.Output, R: Publisher, Failure == R.Failure {
    .init(upstream: self, transform: transform)
  }
}

extension Publishers {
  public struct ConcatMap<R: Publisher, Upstream: Publisher>: Publisher
  where R.Failure == Upstream.Failure {
    public typealias Output = R.Output
    public typealias Failure = Upstream.Failure

    public typealias Transformer = (Upstream.Output) -> R

    private let upstream: Upstream
    private let transform: Transformer

    public init(upstream: Upstream, transform: @escaping Transformer) {
      self.upstream = upstream
      self.transform = transform
    }

    public func receive<S: Subscriber>(subscriber: S)
    where S.Input == Output, S.Failure == Failure {
      let subscription = Subscription(
        upstream: upstream,
        downstream: subscriber,
        transform: transform
      )
      subscriber.receive(subscription: subscription)
    }
  }
}

extension Publishers.ConcatMap {
  final class Subscription<Downstream: Subscriber>: Combine.Subscription
  where
    Downstream.Input == R.Output,
    Downstream.Failure == Failure
  {
    private var sink: OutterSink<Downstream>?

    init(
      upstream: Upstream,
      downstream: Downstream,
      transform: @escaping Transformer
    ) {
      self.sink = OutterSink(
        upstream: upstream,
        downstream: downstream,
        transform: transform
      )
    }

    func request(_ demand: Subscribers.Demand) {
      sink?.demand(demand)
    }

    func cancel() {
      sink = .none
    }
  }

  private final class OutterSink<Downstream: Subscriber>: Subscriber
  where
    Downstream.Input == R.Output,
    Downstream.Failure == Upstream.Failure
  {
    typealias Input = Upstream.Output
    private let lock = NSRecursiveLock()

    private let downstream: Downstream
    private let transform: Transformer

    private var upstreamSubscription: Combine.Subscription?
    private var innerSink: InnerSink<Downstream>?
    private var bufferedDemand: Subscribers.Demand = .none

    init(upstream: Upstream, downstream: Downstream, transform: @escaping (Input) -> R) {
      self.downstream = downstream
      self.transform = transform
      upstream.subscribe(self)
    }

    func demand(_ demand: Subscribers.Demand) {
      lock.lock()
      defer { lock.unlock() }
      if let innerSink {
        innerSink.demand(demand)
      } else {
        bufferedDemand = demand
      }
      upstreamSubscription?.requestIfNeeded(.unlimited)
    }

    func receive(_ input: Input) -> Subscribers.Demand {
      lock.lock()
      defer { lock.unlock() }
      let transformed = transform(input)
      if let innerSink {
        innerSink.enqueue(transformed)
      } else {
        innerSink = InnerSink(outterSink: self, upstream: transformed, downstream: downstream)
        innerSink?.demand(bufferedDemand)
      }
      return .unlimited
    }

    func receive(subscription: Combine.Subscription) {
      lock.lock()
      defer { lock.unlock() }
      upstreamSubscription = subscription
    }

    func receive(completion: Subscribers.Completion<Failure>) {
      lock.lock()
      defer { lock.unlock() }
      innerSink = .none
      downstream.receive(completion: completion)
      cancelUpstream()
    }

    func cancelUpstream() {
      lock.lock()
      defer { lock.unlock() }
      upstreamSubscription?.cancel()
      upstreamSubscription = .none
    }

    deinit {
      cancelUpstream()
    }
  }

  private final class InnerSink<Downstream: Subscriber>: Sink<R, Downstream>
  where
    Downstream.Input == R.Output,
    Downstream.Failure == Failure,
    Upstream.Failure == Downstream.Failure
  {
    private weak var outterSink: OutterSink<Downstream>?
    private let lock = NSRecursiveLock()
    private var hasActive: Bool
    private var publishQueue: [R]

    init(outterSink: OutterSink<Downstream>, upstream: R, downstream: Downstream) {
      self.outterSink = outterSink
      self.hasActive = false
      self.publishQueue = []
      super.init(upstream: upstream, downstream: downstream)
    }

    func enqueue(_ publisher: R) {
      lock.lock()
      defer { lock.unlock() }
      if hasActive {
        publishQueue.append(publisher)
      } else {
        publisher.subscribe(self)
      }
    }

    override func receive(_ input: Sink<R, Downstream>.Input) -> Subscribers.Demand {
      buffer.buffer(value: input)
    }

    override func receive(subscription: Combine.Subscription) {
      lock.lock()
      defer { lock.unlock() }
      hasActive = true
      super.receive(subscription: subscription)
      subscription.requestIfNeeded(buffer.demandState.remaining)
    }

    override func receive(completion: Subscribers.Completion<Sink<R, Downstream>.Failure>) {
      lock.lock()
      defer { lock.unlock() }
      hasActive = false
      switch completion {
      case .finished:
        if !publishQueue.isEmpty {
          publishQueue.removeFirst().subscribe(self)
        }
      case .failure(let error):
        buffer.complete(completion: .failure(error))
        outterSink?.receive(completion: completion)
      }
    }
  }
}

extension Publishers.ConcatMap.Subscription: CustomStringConvertible {
  var description: String {
    "ConcatMap.Subscription<\(Downstream.Input.self), \(Downstream.Failure.self)>"
  }
}

#endif
