#if canImport(UIKit)

import Combine
import class UIKit.UISlider

extension UISlider: CombineCompatible {}

extension Reactive where Base: UISlider {
  @MainActor
  public var value: ControlProperty<Float> {
    base.rx.controlPropertyWithDefaultEvents(
      getter: { slider in slider.value },
      setter: { slider, value in slider.value = value }
    )
  }
}

#endif
