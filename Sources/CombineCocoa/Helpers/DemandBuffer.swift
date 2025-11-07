#if canImport(Combine)

import Combine
import class Foundation.NSRecursiveLock

class DemandBuffer<S: Subscriber> {
  private let lock = NSRecursiveLock()
  private var buffer = [S.Input]()
  private let subscriber: S
  private var completion: Subscribers.Completion<S.Failure>?
  private(set) var demandState: Demand

  init(subscriber: S) {
    self.subscriber = subscriber
    self.demandState = Demand()
  }

  func buffer(value: S.Input) -> Subscribers.Demand {
    precondition(self.completion == nil, "Completed publisher can't send values")
    lock.lock()
    defer { lock.unlock() }
    switch demandState.requested {
    case .unlimited:
      return subscriber.receive(value)
    default:
      buffer.append(value)
      return flush()
    }
  }

  func complete(completion: Subscribers.Completion<S.Failure>) {
    precondition(self.completion == nil, "Completion have already occured")
    self.completion = completion
    flush()
  }

  @discardableResult
  func demand(_ demand: Subscribers.Demand) -> Subscribers.Demand {
    flush(adding: demand)
  }

  @discardableResult
  private func flush(adding newDemand: Subscribers.Demand? = Optional.none) -> Subscribers.Demand {
    lock.lock()
    defer { lock.unlock() }
    if let newDemand {
      demandState.requested += newDemand
    }
    guard demandState.requested > 0 || newDemand == Subscribers.Demand.none else { return .none }
    while !buffer.isEmpty && demandState.processed < demandState.requested {
      demandState.requested += subscriber.receive(buffer.remove(at: 0))
      demandState.processed += 1
    }
    if let completion {
      buffer = []
      demandState = .init()
      self.completion = .none
      subscriber.receive(completion: completion)
      return .none
    }
    let sent = demandState.remaining
    demandState.sent += sent
    return sent
  }
}

extension DemandBuffer {
  struct Demand {
    var processed: Subscribers.Demand = .none
    var requested: Subscribers.Demand = .none
    var sent: Subscribers.Demand = .none

    var remaining: Subscribers.Demand {
      requested - sent
    }
  }
}

#endif
