#if canImport(UIKit)

import Combine
import UIKit

extension NSTextStorage: CombineCompatible {}

public extension Reactive where Base: NSTextStorage {
  @MainActor
  var didProcessEditingRangeChangeInLength:
    AnyPublisher<(editedMask: NSTextStorage.EditActions, editedRange: NSRange, delta: Int), Never>
  {
    let selector = #selector(NSTextStorageDelegate.textStorage(_:didProcessEditing:range:changeInLength:))
    return
      delegate
      .methodInvoked(selector)
      .map { args -> (editedMask: NSTextStorage.EditActions, editedRange: NSRange, delta: Int) in
        let editedMask = NSTextStorage.EditActions(rawValue: try! castOrThrow(UInt.self, args[1]))
        let editedRange = try! castOrThrow(NSValue.self, args[2]).rangeValue
        let delta = try! castOrThrow(Int.self, args[3])
        return (editedMask, editedRange, delta)
      }
      .eraseToAnyPublisher()
  }

  @MainActor
  public var delegate: DelegateProxy<NSTextStorage, NSTextStorageDelegate> {
    TextStorageDelegateProxy.proxy(for: base)
  }
}

extension NSTextStorage: HasDelegate {
  public typealias Delegate = NSTextStorageDelegate
}

private class TextStorageDelegateProxy: DelegateProxy<NSTextStorage, NSTextStorageDelegate>,
  @preconcurrency DelegateProxyType
{
  public weak private(set) var textStorage: NSTextStorage?

  @MainActor
  public init(textStorage: NSTextStorage) {
    self.textStorage = textStorage
    super.init(parentObject: textStorage, delegateProxy: TextStorageDelegateProxy.self)
  }

  @MainActor
  public static func registerKnownImplementations() {
    self.register { TextStorageDelegateProxy(textStorage: $0) }
  }
}

extension TextStorageDelegateProxy: NSTextStorageDelegate {}

#endif
