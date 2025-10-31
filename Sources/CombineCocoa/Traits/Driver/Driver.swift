import Combine
import Foundation

public typealias Driver<Element> = SharedSequence<DriverSharingStrategy, Element>

public struct DriverSharingStrategy: SharingStrategyProtocol {
  public static var scheduler: some Scheduler { RunLoop.main }

  public static func share<Element>(_ source: Observable<Element>) -> Observable<Element> {
    source.share().eraseToAnyPublisher()
  }
}

extension SharedSequenceConvertibleType where SharingStrategy == DriverSharingStrategy {
  public func asDriver() -> Driver<Element> {
    self.asSharedSequence()
  }
}
