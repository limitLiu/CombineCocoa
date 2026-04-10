#if canImport(Combine)

@preconcurrency import Combine
import Foundation

public struct MainScheduler: Scheduler, Sendable {
  public typealias SchedulerTimeType = RunLoop.SchedulerTimeType
  public typealias SchedulerOptions = Never

  public static let instance = MainScheduler()
  nonisolated(unsafe) public static let asyncInstance: RunLoop = .main

  public var now: SchedulerTimeType {
    RunLoop.main.now
  }

  public var minimumTolerance: SchedulerTimeType.Stride {
    RunLoop.main.minimumTolerance
  }

  public func schedule(options: Never?, _ action: @escaping () -> Void) {
    if Thread.isMainThread {
      action()
    } else {
      RunLoop.main.schedule(action)
    }
  }

  public func schedule(
    after date: SchedulerTimeType, tolerance: SchedulerTimeType.Stride,
    options: Never?, _ action: @escaping () -> Void,
  ) {
    RunLoop.main.schedule(after: date, tolerance: tolerance, action)
  }

  public func schedule(
    after date: SchedulerTimeType, interval: SchedulerTimeType.Stride,
    tolerance: SchedulerTimeType.Stride, options: Never?,
    _ action: @escaping () -> Void,
  ) -> any Cancellable {
    RunLoop.main.schedule(after: date, interval: interval, tolerance: tolerance, action)
  }
}

#endif
