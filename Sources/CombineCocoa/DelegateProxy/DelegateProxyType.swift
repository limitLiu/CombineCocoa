import Combine
import Foundation

private nonisolated class DelegateProxyFactory {
  @MainActor
  private static var _sharedFactories: [UnsafeRawPointer: DelegateProxyFactory] = [:]

  @MainActor
  fileprivate static func sharedFactory<DelegateProxy: DelegateProxyType>(
    for proxyType: DelegateProxy.Type
  ) -> DelegateProxyFactory {
    let identifier = DelegateProxy.identifier
    if let factory = _sharedFactories[identifier] {
      return factory
    }
    let factory = DelegateProxyFactory(for: proxyType)
    _sharedFactories[identifier] = factory
    DelegateProxy.registerKnownImplementations()
    return factory
  }

  private var _factories: [ObjectIdentifier: ((AnyObject) -> AnyObject)]
  private var _delegateProxyType: Any.Type
  private var _identifier: UnsafeRawPointer

  private init<DelegateProxy: DelegateProxyType>(for proxyType: DelegateProxy.Type) {
    self._factories = [:]
    self._delegateProxyType = proxyType
    self._identifier = proxyType.identifier
  }

  @MainActor
  fileprivate func extend<DelegateProxy: DelegateProxyType, ParentObject>(
    make: @escaping (ParentObject) -> DelegateProxy
  ) {
    precondition(self._identifier == DelegateProxy.identifier, "Delegate proxy has inconsistent identifier")
    guard self._factories[ObjectIdentifier(ParentObject.self)] == nil else {
      exFatalError(
        "The factory of \(ParentObject.self) is duplicated. DelegateProxy is not allowed of duplicated base object type."
      )
    }
    self._factories[ObjectIdentifier(ParentObject.self)] = { make(castOrFatalError($0)) }
  }

  @MainActor
  fileprivate func createProxy(for object: AnyObject) -> AnyObject {
    var maybeMirror: Mirror? = Mirror(reflecting: object)
    while let mirror = maybeMirror {
      if let factory = self._factories[ObjectIdentifier(mirror.subjectType)] {
        return factory(object)
      }
      maybeMirror = mirror.superclassMirror
    }
    exFatalError("DelegateProxy has no factory of \(object). Implement DelegateProxy subclass for \(object) first.")
  }
}

func castOrFatalError<T>(_ value: Any!) -> T {
  let maybeResult: T? = value as? T
  guard let result = maybeResult else {
    exFatalError("Failure converting from \(String(describing: value)) to \(T.self)")
  }
  return result
}

func castOrFatalError<T>(_ value: AnyObject!, message: String) -> T {
  let maybeResult: T? = value as? T
  guard let result = maybeResult else {
    exFatalError(message)
  }
  return result
}

func castOptionalOrFatalError<T>(_ value: Any?) -> T? {
  if value == nil {
    return nil
  }
  let v: T = castOrFatalError(value)
  return v
}

public protocol DelegateProxyType: AnyObject {
  associatedtype ParentObject: AnyObject
  associatedtype Delegate

  static func registerKnownImplementations()

  static var identifier: UnsafeRawPointer { get }

  static func currentDelegate(for object: ParentObject) -> Delegate?

  static func setCurrentDelegate(_ delegate: Delegate?, to object: ParentObject)

  func forwardToDelegate() -> Delegate?

  func setForwardToDelegate(_ forwardToDelegate: Delegate?, retainDelegate: Bool)
}

extension DelegateProxyType {
  public static var identifier: UnsafeRawPointer {
    let delegateIdentifier = ObjectIdentifier(Delegate.self)
    let integerIdentifier = Int(bitPattern: delegateIdentifier)
    return UnsafeRawPointer(bitPattern: integerIdentifier)!
  }
}

extension DelegateProxyType {
  static func _currentDelegate(for object: ParentObject) -> AnyObject? {
    currentDelegate(for: object).map { $0 as AnyObject }
  }

  static func _setCurrentDelegate(_ delegate: AnyObject?, to object: ParentObject) {
    setCurrentDelegate(castOptionalOrFatalError(delegate), to: object)
  }

  func _forwardToDelegate() -> AnyObject? {
    self.forwardToDelegate().map { $0 as AnyObject }
  }

  func _setForwardToDelegate(_ forwardToDelegate: AnyObject?, retainDelegate: Bool) {
    self.setForwardToDelegate(castOptionalOrFatalError(forwardToDelegate), retainDelegate: retainDelegate)
  }
}

extension DelegateProxyType {
  @MainActor
  public static func register<Parent>(make: @escaping (Parent) -> Self) {
    self.factory.extend(make: make)
  }

  @MainActor
  public static func createProxy(for object: AnyObject) -> Self {
    castOrFatalError(factory.createProxy(for: object))
  }

  @MainActor
  public static func proxy(for object: ParentObject) -> Self {
    let maybeProxy = self.assignedProxy(for: object)
    let proxy: AnyObject
    if let existingProxy = maybeProxy {
      proxy = existingProxy
    } else {
      proxy = castOrFatalError(self.createProxy(for: object))
      self.assignProxy(proxy, to: object)
      assert(self.assignedProxy(for: object) === proxy)
    }
    let currentDelegate = self._currentDelegate(for: object)
    let delegateProxy: Self = castOrFatalError(proxy)
    if currentDelegate !== delegateProxy {
      delegateProxy._setForwardToDelegate(currentDelegate, retainDelegate: false)
      assert(delegateProxy._forwardToDelegate() === currentDelegate)
      self._setCurrentDelegate(proxy, to: object)
      assert(self._currentDelegate(for: object) === proxy)
      assert(delegateProxy._forwardToDelegate() === currentDelegate)
    }
    return delegateProxy
  }

  @MainActor
  public static func installForwardDelegate(
    _ forwardDelegate: Delegate,
    retainDelegate: Bool,
    onProxyForObject object: ParentObject
  ) -> AnyCancellable {
    weak var weakForwardDelegate: AnyObject? = forwardDelegate as AnyObject
    let proxy = self.proxy(for: object)
    assert(
      proxy._forwardToDelegate() === nil,
      "This is a feature to warn you that there is already a delegate (or data source) set somewhere previously."
        + "The action you are trying to perform will clear that delegate (data source) and that means that some of your features that depend on that delegate (data source) being set will likely stop working.\n"
        + "If you are ok with this, try to set delegate (data source) to `nil` in front of this operation.\n"
        + " This is the source object value: \(object)\n"
        + " This is the original delegate (data source) value: \(proxy.forwardToDelegate()!)\n"
        + "Hint: Maybe delegate was already set in xib or storyboard and now it's being overwritten in code.\n"
    )
    proxy.setForwardToDelegate(forwardDelegate, retainDelegate: retainDelegate)
    return AnyCancellable {
      let delegate: AnyObject? = weakForwardDelegate
      assert(
        delegate == nil || proxy._forwardToDelegate() === delegate,
        "Delegate was changed from time it was first set. Current \(String(describing: proxy.forwardToDelegate())), and it should have been \(proxy)"
      )
      proxy.setForwardToDelegate(nil, retainDelegate: retainDelegate)
    }
  }
}

extension DelegateProxyType {
  @MainActor
  private static var factory: DelegateProxyFactory {
    DelegateProxyFactory.sharedFactory(for: self)
  }

  private static func assignedProxy(for object: ParentObject) -> AnyObject? {
    let maybeDelegate = objc_getAssociatedObject(object, self.identifier)
    return castOptionalOrFatalError(maybeDelegate)
  }

  private static func assignProxy(_ proxy: AnyObject, to object: ParentObject) {
    objc_setAssociatedObject(object, self.identifier, proxy, .OBJC_ASSOCIATION_RETAIN)
  }
}

public protocol HasDelegate: AnyObject {
  associatedtype Delegate
  var delegate: Delegate? { get set }
}

extension DelegateProxyType where ParentObject: HasDelegate, Self.Delegate == ParentObject.Delegate {
  public static func currentDelegate(for object: ParentObject) -> Delegate? {
    object.delegate
  }

  public static func setCurrentDelegate(_ delegate: Delegate?, to object: ParentObject) {
    object.delegate = delegate
  }
}

@MainActor
public protocol HasDataSource: AnyObject {
  associatedtype DataSource

  var dataSource: DataSource? { get set }
}

extension DelegateProxyType where ParentObject: HasDataSource, Self.Delegate == ParentObject.DataSource {
  @MainActor
  public static func currentDelegate(for object: ParentObject) -> Delegate? {
    object.dataSource
  }

  @MainActor
  public static func setCurrentDelegate(_ delegate: Delegate?, to object: ParentObject) {
    object.dataSource = delegate
  }
}
