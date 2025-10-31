#if canImport(UIKit)
import Combine
import UIKit

extension UITextView: CombineCompatible {}

extension Reactive where Base: UITextView {
  @MainActor
  public var text: ControlProperty<String?> {
    value
  }

  @MainActor
  public var value: ControlProperty<String?> {
    let source = Deferred { [weak textView = base] in
      textView?.textStorage
        .rx.didProcessEditingRangeChangeInLength
        .map { _ in textView?.text }
        .prepend(textView?.text)
        .eraseToAnyPublisher() ?? Empty().eraseToAnyPublisher()
    }.eraseToAnyPublisher()

    let bindingObserver = Binder(self.base) { (textView, text: String?) in
      if textView.text != text {
        textView.text = text
      }
    }
    return ControlProperty(values: source, valueSink: bindingObserver)
  }
  
  @MainActor
  public var didChange: ControlEvent<()> {
    return ControlEvent<()>(events: self.delegate.methodInvoked(#selector(UITextViewDelegate.textViewDidChange(_:)))
      .map { _ in () })
  }
}

#endif
