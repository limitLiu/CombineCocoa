#if canImport(Combine)

import Combine
import Foundation

extension Publisher {
  public func share(
    replay count: Int
  ) -> Publishers.Autoconnect<Publishers.Multicast<Self, ReplaySubject<Output, Failure>>> {
    multicast {
      ReplaySubject(bufferSize: count)
    }.autoconnect()
  }
}

#endif
