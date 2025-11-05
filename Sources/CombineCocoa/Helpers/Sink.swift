#if canImport(Combine)

import Combine

class Sink<Upstream: Publisher, Downstream: Subscriber>: Subscriber {
  typealias Input = Upstream.Output
  typealias Failure = Upstream.Failure

  typealias TransformFailure = (Upstream.Failure) -> Downstream.Failure?
  typealias Transform = (Upstream.Output) -> Downstream.Input?

  private(set) var buffer: DemandBuffer<Downstream>
  private var upstreamSubscription: Subscription?
  private let transform: Transform?
  private let transformFailure: TransformFailure?
  private var upstreamIsCancelled = false

  init(
    upstream: Upstream,
    downstream: Downstream,
    transform: Transform? = .none,
    transformFailure: TransformFailure? = .none
  ) {
    self.buffer = DemandBuffer(subscriber: downstream)
    self.transform = transform
    self.transformFailure = transformFailure
    upstream.handleEvents(
      receiveCancel: { [weak self] in self?.upstreamIsCancelled = true }
    )
    .subscribe(self)
  }

  func demand(_ demand: Subscribers.Demand) {
    let newDemand = buffer.demand(demand)
    upstreamSubscription?.requestIfNeeded(newDemand)
  }

  func receive(_ input: Input) -> Subscribers.Demand {
    guard let transform else {
      fatalError(
        """
            ❌ Missing output transformation
            =========================

            You must either:
                - Provide a transformation function from the upstream's output to the downstream's input; or
                - Subclass `Sink` with your own publisher's Sink and manage the buffer yourself
        """
      )
    }
    guard let input = transform(input) else { return .none }
    return buffer.buffer(value: input)
  }

  func receive(completion: Subscribers.Completion<Failure>) {
    switch completion {
    case .finished:
      buffer.complete(completion: .finished)
    case .failure(let error):
      guard let transform = transformFailure else {
        fatalError(
          """
              ❌ Missing failure transformation
              =========================

              You must either:
                  - Provide a transformation function from the upstream's failure to the downstream's failuer; or
                  - Subclass `Sink` with your own publisher's Sink and manage the buffer yourself
          """
        )
      }
      guard let error = transform(error) else { return }
      buffer.complete(completion: .failure(error))
    }
    cancelUpstream()
  }

  func receive(subscription: any Subscription) {
    upstreamSubscription = subscription
  }

  func cancelUpstream() {
    guard !upstreamIsCancelled else { return }
    upstreamSubscription?.cancel()
    upstreamSubscription = .none
  }

  deinit { cancelUpstream() }
}

extension Subscription {
  func requestIfNeeded(_ demand: Subscribers.Demand) {
    guard demand > .none else { return }
    request(demand)
  }
}

#endif
