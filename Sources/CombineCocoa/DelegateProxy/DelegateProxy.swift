#if canImport(Runtime)

import Combine
import Foundation
import Runtime

open class DelegateProxy<P: AnyObject, D>: ObjCDelegateProxy {
  public typealias ParentObject = P
  public typealias Delegate = D

  private var _sentMessageForSelector = [Selector: MessageDispatcher]()
  private var _methodInvokedForSelector = [Selector: MessageDispatcher]()

  private weak var _parentObject: ParentObject?

  private let _currentDelegateFor: (ParentObject) -> AnyObject?
  private let _setCurrentDelegateTo: (AnyObject?, ParentObject) -> Void

  @MainActor
  public init<Proxy: DelegateProxyType>(parentObject: ParentObject, delegateProxy: Proxy.Type)
  where Proxy: DelegateProxy<ParentObject, Delegate>, Proxy.ParentObject == ParentObject, Proxy.Delegate == Delegate {
    self._parentObject = parentObject
    self._currentDelegateFor = delegateProxy._currentDelegate
    self._setCurrentDelegateTo = delegateProxy._setCurrentDelegate
    super.init()
  }

  @MainActor
  open func sentMessage(_ selector: Selector) -> Observable<[Any]> {
    let subject = self._sentMessageForSelector[selector]
    if let subject {
      return subject.asObservable()
    } else {
      let subject = MessageDispatcher(selector: selector, delegateProxy: self)
      self._sentMessageForSelector[selector] = subject
      return subject.asObservable()
    }
  }

  @MainActor
  open func methodInvoked(_ selector: Selector) -> Observable<[Any]> {
    let subject = self._methodInvokedForSelector[selector]
    if let subject {
      return subject.asObservable()
    } else {
      let subject = MessageDispatcher(selector: selector, delegateProxy: self)
      self._methodInvokedForSelector[selector] = subject
      return subject.asObservable()
    }
  }

  @MainActor
  fileprivate func checkSelectorIsObservable(_ selector: Selector) {
    if self.hasWiredImplementation(for: selector) {
      print("⚠️ Delegate proxy is already implementing `\(selector)`, a more performant way of registering might exist.")
      return
    }

    if self.voidDelegateMethodsContain(selector) {
      return
    }

    if !(self._forwardToDelegate?.responds(to: selector) ?? true) {
      print(
        "⚠️ Using delegate proxy dynamic interception method but the target delegate object doesn't respond to the requested selector. "
          + "In case pure Swift delegate proxy is being used please use manual observing method by using`PublishSubject`s. "
          + " (selector: `\(selector)`, forwardToDelegate: `\(self._forwardToDelegate ?? self)`)"
      )
    }
  }

  open override func _sentMessage(_ selector: Selector, withArguments arguments: [Any]) {
    self._sentMessageForSelector[selector]?.on(.next(arguments))
  }

  open override func _methodInvoked(_ selector: Selector, withArguments arguments: [Any]) {
    self._methodInvokedForSelector[selector]?.on(.next(arguments))
  }

  open func forwardToDelegate() -> Delegate? {
    return castOptionalOrFatalError(self._forwardToDelegate)
  }

  @MainActor
  open func setForwardToDelegate(_ delegate: Delegate?, retainDelegate: Bool) {
    self._setForwardToDelegate(delegate, retainDelegate: retainDelegate)

    let sentSelectors: [Selector] = self._sentMessageForSelector.values.filter { $0.hasObservers }.map { $0.selector }
    let invokedSelectors: [Selector] = self._methodInvokedForSelector.values.filter { $0.hasObservers }.map {
      $0.selector
    }
    let allUsedSelectors = sentSelectors + invokedSelectors

    for selector in Set(allUsedSelectors) {
      self.checkSelectorIsObservable(selector)
    }
    self.reset()
  }

  func hasObservers(selector: Selector) -> Bool {
    return (self._sentMessageForSelector[selector]?.hasObservers ?? false)
      || (self._methodInvokedForSelector[selector]?.hasObservers ?? false)
  }

  override open func responds(to aSelector: Selector!) -> Bool {
    guard let aSelector = aSelector else { return false }
    return super.responds(to: aSelector)
      || (self._forwardToDelegate?.responds(to: aSelector) ?? false)
      || (self.voidDelegateMethodsContain(aSelector) && self.hasObservers(selector: aSelector))
  }

  fileprivate func reset() {
    guard let parentObject = self._parentObject else { return }
    let maybeCurrentDelegate = self._currentDelegateFor(parentObject)
    if maybeCurrentDelegate === self {
      self._setCurrentDelegateTo(nil, parentObject)
      self._setCurrentDelegateTo(castOrFatalError(self), parentObject)
    }
  }

  deinit {
    for v in self._sentMessageForSelector.values {
      v.on(.completed)
    }
    for v in self._methodInvokedForSelector.values {
      v.on(.completed)
    }
  }
}

private final class MessageDispatcher {
  private let dispatcher: PublishRelay<[Any]>
  private let result: Observable<[Any]>

  fileprivate let selector: Selector

  @MainActor
  init<P, D>(selector: Selector, delegateProxy _delegateProxy: DelegateProxy<P, D>) {
    weak var weakDelegateProxy = _delegateProxy

    let dispatcher = PublishRelay<[Any]>()
    self.dispatcher = dispatcher
    self.selector = selector

    self.result =
      dispatcher
      .handleEvents(
        receiveSubscription: { _ in
          weakDelegateProxy?.checkSelectorIsObservable(selector)
          weakDelegateProxy?.reset()
        },
        receiveCancel: {
          weakDelegateProxy?.reset()
        }
      )
      .share()
      .receive(on: RunLoop.main)
      .eraseToAnyPublisher()
  }

  var on: (Event<[Any]>) -> Void {
    return self.dispatcher.on
  }

  var hasObservers: Bool {
    return self.dispatcher.hasObservers
  }

  func asObservable() -> Observable<[Any]> {
    return self.result
  }
}
#endif
