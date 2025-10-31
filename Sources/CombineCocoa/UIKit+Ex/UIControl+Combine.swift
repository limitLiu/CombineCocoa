#if canImport(UIKit)

import Combine
import UIKit

extension UIControl: CombineCompatible {}

extension Reactive where Base: UIControl {
  public func controlEvent(for events: UIControl.Event) -> AnyPublisher<Void, Never> {
    Publishers.ControlEvent(control: base, events: events)
      .prefix(untilOutputFrom: base.rx.deallocated)
      .eraseToAnyPublisher()
  }

  @MainActor
  public func controlProperty<T>(
    editingEvents: UIControl.Event,
    getter: @escaping (Base) -> T,
    setter: @escaping (Base, T) -> Void
  ) -> ControlProperty<T> {
    let source = Combine.Publishers.ControlTarget(
      control: base,
      addTargetAction: { control, target, action in
        control.addTarget(target, action: action, for: editingEvents)
      },
      removeTargetAction: { control, target, action in
        control?.removeTarget(target, action: action, for: editingEvents)
      }
    )
    .map { [weak base] in
      guard let base else { return getter(base!) }
      return getter(base)
    }
    .prefix(untilOutputFrom: base.rx.deallocated)
    .prepend(getter(base))
    .eraseToAnyPublisher()
    let binder = Binder(base, binding: setter)
    return ControlProperty(values: source, valueSink: binder)
  }

  @MainActor
  internal func controlPropertyWithDefaultEvents<T>(
    editingEvents: UIControl.Event = [.allEditingEvents, .valueChanged],
    getter: @escaping (Base) -> T,
    setter: @escaping (Base, T) -> Void
  ) -> ControlProperty<T> {
    return controlProperty(
      editingEvents: editingEvents,
      getter: getter,
      setter: setter
    )
  }

}

#endif
