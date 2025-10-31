#if canImport(UIKit)
import Combine
import UIKit

extension UITextField: CombineCompatible {}

extension Reactive where Base: UITextField {
  @MainActor
  public var text: ControlProperty<String?> {
    value
  }

  @MainActor
  public var value: ControlProperty<String?> {
    base.rx.controlPropertyWithDefaultEvents(
      getter: { textField in textField.text },
      setter: { textField, value in
        if textField.text != value {
          textField.text = value
        }
      }
    )
  }
}

#endif
