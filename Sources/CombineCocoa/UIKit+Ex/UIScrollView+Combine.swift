#if canImport(UIKit)
import Combine
import UIKit

extension UIScrollView: CombineCompatible {}

extension Reactive where Base: UIScrollView {
  @MainActor
  public var delegate: DelegateProxy<UIScrollView, UIScrollViewDelegate> {
    return ScrollViewDelegateProxy.proxy(for: base)
  }

  @MainActor
  public func setDelegate(_ delegate: UIScrollViewDelegate) -> AnyCancellable {
    ScrollViewDelegateProxy
      .installForwardDelegate(delegate, retainDelegate: false, onProxyForObject: base)
  }
}

#endif
