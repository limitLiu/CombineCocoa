/// https://github.com/OpenCombine/OpenCombine/blob/master/Sources/OpenCombine/Helpers/ConduitBase.swift

#if canImport(Combine)

import Combine

internal class ConduitBase<Output, Failure: Error>: Subscription {
  internal init() {}

  internal func offer(_ output: Output) {
    exAbstractMethod()
  }

  internal func finish(completion: Subscribers.Completion<Failure>) {
    exAbstractMethod()
  }

  internal func request(_ demand: Subscribers.Demand) {
    exAbstractMethod()
  }

  internal func cancel() {
    exAbstractMethod()
  }
}

extension ConduitBase: Equatable {
  internal static func == (
    lhs: ConduitBase<Output, Failure>,
    rhs: ConduitBase<Output, Failure>
  ) -> Bool {
    return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
  }
}

extension ConduitBase: Hashable {
  internal func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}

#endif
