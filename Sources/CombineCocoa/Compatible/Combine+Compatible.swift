import Combine
import ObjectiveC

@dynamicMemberLookup
public nonisolated struct Reactive<Base> {
  public let base: Base
  public init(_ base: Base) {
    self.base = base
  }
}

public nonisolated protocol CombineCompatible {
  associatedtype Base
  static var rx: Reactive<Base>.Type { get set }
  var rx: Reactive<Base> { get set }
}

public extension CombineCompatible {
  nonisolated static var rx: Reactive<Self>.Type {
    get { Reactive<Self>.self }
    set {}
  }
  nonisolated var rx: Reactive<Self> {
    get { Reactive(self) }
    set {}
  }
}

private final class DeinitSignal {
  let subject = PassthroughSubject<Void, Never>()
  deinit {
    subject.send(())
    subject.send(completion: .finished)
  }
}

nonisolated(unsafe) private var deallocatedSubjectContext: UInt8 = 0

extension NSObject: CombineCompatible {}

public extension Reactive where Base: AnyObject {
  var deallocated: AnyPublisher<Void, Never> {
    self.synchronized {
      if let signal = objc_getAssociatedObject(base, &deallocatedSubjectContext) as? DeinitSignal {
        return signal.subject.eraseToAnyPublisher()
      }
      let signal = DeinitSignal()
      objc_setAssociatedObject(base, &deallocatedSubjectContext, signal, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
      return signal.subject.eraseToAnyPublisher()
    }
  }

  func synchronized<T>(_ action: () -> T) -> T {
    objc_sync_enter(self.base)
    let result = action()
    objc_sync_exit(self.base)
    return result
  }
}

extension Reactive where Base: NSObject {
  private func kvoProperty<Value>(_ keyPath: ReferenceWritableKeyPath<Base, Value>) -> Binder<Value> {
    Binder(base) { target, value in target[keyPath: keyPath] = value }
  }

  public subscript<Value>(
    dynamicMember keyPath: ReferenceWritableKeyPath<Base, Value>
  ) -> Binder<Value> {
    kvoProperty(keyPath)
  }
}
