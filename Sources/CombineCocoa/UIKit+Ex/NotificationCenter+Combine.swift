import Combine
import Foundation

extension NotificationCenter: CombineCompatible {}

public extension Reactive where Base: NotificationCenter {
  public func notification(_ name: Notification.Name?, object: AnyObject? = .none) -> Observable<Notification> {
    if let name {
      base.publisher(for: name, object: object).eraseToAnyPublisher()
    } else {
      Empty<Notification, Never>().eraseToAnyPublisher()
    }
  }
}
