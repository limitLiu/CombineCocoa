import Combine
import CoreData
import Foundation

public nonisolated struct FetchedResultsControllerPublisher<T: NSManagedObject>: Publisher {
  public typealias Output = [T]
  public typealias Failure = Error

  private let fetchRequest: NSFetchRequest<T>
  private let context: NSManagedObjectContext
  private let sectionNameKeyPath: String?
  private let cacheName: String?

  init(
    fetchRequest: NSFetchRequest<T>,
    context: NSManagedObjectContext,
    sectionNameKeyPath: String? = .none,
    cacheName: String? = .none
  ) {
    self.fetchRequest = fetchRequest
    self.context = context
    self.sectionNameKeyPath = sectionNameKeyPath
    self.cacheName = cacheName
  }

  public func receive<S>(subscriber: S) where S: Subscriber, any Failure == S.Failure, [T] == S.Input {
    let subscription = Subscription(
      subscriber: subscriber,
      context: context,
      fetchRequest: fetchRequest,
      sectionNameKeyPath: sectionNameKeyPath,
      cacheName: cacheName
    )
    subscriber.receive(subscription: subscription)
  }
}

extension FetchedResultsControllerPublisher {
  private final nonisolated class Subscription<S: Subscriber>: NSObject, NSFetchedResultsControllerDelegate, Combine
      .Subscription
  where S.Input == [T], S.Failure == Error {
    private var subscriber: S?
    private let controller: NSFetchedResultsController<T>
    private let context: NSManagedObjectContext

    init(
      subscriber: S,
      context: NSManagedObjectContext,
      fetchRequest: NSFetchRequest<T>,
      sectionNameKeyPath: String?,
      cacheName: String?
    ) {
      self.subscriber = subscriber
      self.context = context
      self.controller = NSFetchedResultsController(
        fetchRequest: fetchRequest,
        managedObjectContext: context,
        sectionNameKeyPath: sectionNameKeyPath,
        cacheName: cacheName
      )
      super.init()
      context.perform {
        self.controller.delegate = self
        do {
          try self.controller.performFetch()
          self.sendFetchedObjects()
        } catch {
          self.subscriber?.receive(completion: .failure(error))
        }
      }
    }

    func request(_ demand: Subscribers.Demand) {}

    func cancel() {
      subscriber = .none
      controller.delegate = .none
    }

    private func sendFetchedObjects() {
      context.perform { [weak self] in
        guard let self, let subscriber else { return }
        _ = subscriber.receive(controller.fetchedObjects ?? [])
      }
    }
  }
}
