#if canImport(UIKit)
import Combine
import UIKit

extension UIButton: CombineCompatible {}

extension Reactive where Base: UIButton {
  public var tap: AnyPublisher<Void, Never> {
    controlEvent(for: .touchUpInside)
  }
}

#endif
