#if canImport(UIKit)

import UIKit

extension UIScrollView: @preconcurrency HasDelegate {
  public typealias Delegate = UIScrollViewDelegate
}

@MainActor
open class ScrollViewDelegateProxy: DelegateProxy<UIScrollView, UIScrollViewDelegate>, @preconcurrency DelegateProxyType
{
  public weak private(set) var scrollView: UIScrollView?

  public init(scrollView: ParentObject) {
    self.scrollView = scrollView
    super.init(parentObject: scrollView, delegateProxy: ScrollViewDelegateProxy.self)
  }

  public static func registerKnownImplementations() {
    self.register { ScrollViewDelegateProxy(scrollView: $0) }
    self.register { TableViewDelegateProxy(tableView: $0) }
    self.register { CollectionViewDelegateProxy(collectionView: $0) }
  }

  private var _contentOffsetBehaviorSubject: BehaviorRelay<CGPoint>?
  private var _contentOffsetPublishSubject: PublishRelay<()>?

  internal var contentOffsetBehaviorSubject: BehaviorRelay<CGPoint> {
    if let subject = _contentOffsetBehaviorSubject {
      return subject
    }

    let subject = BehaviorRelay<CGPoint>(self.scrollView?.contentOffset ?? CGPoint.zero)
    _contentOffsetBehaviorSubject = subject

    return subject
  }

  internal var contentOffsetPublishSubject: PublishRelay<()> {
    if let subject = _contentOffsetPublishSubject {
      return subject
    }

    let subject = PublishRelay<()>()
    _contentOffsetPublishSubject = subject
    return subject
  }

  isolated deinit {
    if let subject = _contentOffsetBehaviorSubject {
      subject.on(.completed)
    }

    if let subject = _contentOffsetPublishSubject {
      subject.on(.completed)
    }
  }
}

extension ScrollViewDelegateProxy: UIScrollViewDelegate {
  public func scrollViewDidScroll(_ scrollView: UIScrollView) {
    if let subject = _contentOffsetBehaviorSubject {
      subject.on(.next(scrollView.contentOffset))
    }
    if let subject = _contentOffsetPublishSubject {
      subject.on(.next(()))
    }
    self._forwardToDelegate?.scrollViewDidScroll?(scrollView)
  }

  public func scrollViewDidZoom(_ scrollView: UIScrollView) {
  }
}

#endif
