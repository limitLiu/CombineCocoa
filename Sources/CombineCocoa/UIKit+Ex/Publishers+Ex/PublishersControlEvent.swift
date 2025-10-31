#if canImport(UIKit)

import Combine
import UIKit.UIControl

public extension Combine.Publishers {
  struct ControlEvent<Control: UIControl>: @preconcurrency Publisher {
    public typealias Output = Void
    public typealias Failure = Never

    private let control: Control
    private let controlEvents: Control.Event

    public init(control: Control, events: UIControl.Event) {
      self.control = control
      self.controlEvents = events
    }

    @MainActor
    public func receive<S: Subscriber>(subscriber: S) where S.Failure == Failure, S.Input == Output {
      let subscription = Subscription(subscriber: subscriber, control: control, event: controlEvents)
      subscriber.receive(subscription: subscription)
    }
  }
}

extension Combine.Publishers.ControlEvent {
  private final class Subscription<S: Subscriber, C: UIControl>: Combine.Subscription where S.Input == Void {
    private var subscriber: S?
    weak private var control: C?

    @MainActor
    init(subscriber: S, control: C, event: Control.Event) {
      self.subscriber = subscriber
      self.control = control
      control.addTarget(self, action: #selector(handleControlEvent), for: event)
    }

    func request(_ demand: Subscribers.Demand) {}

    func cancel() {
      subscriber = .none
    }

    @objc private func handleControlEvent() {
      _ = subscriber?.receive()
    }
  }
}

#endif
