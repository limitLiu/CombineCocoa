import Combine
import CoreData
import Foundation

@CoreData
extension NSManagedObjectContext: CombineCompatible {}

public extension Reactive where Base: NSManagedObjectContext {
  func entities<T: NSManagedObject>(
    fetchRequest: NSFetchRequest<T>,
    sectionNameKeyPath: String? = .none,
    cacheName: String? = .none
  ) -> AnyPublisher<[T], Error> {
    FetchedResultsControllerPublisher(
      fetchRequest: fetchRequest,
      context: base,
      sectionNameKeyPath: sectionNameKeyPath,
      cacheName: cacheName
    )
    .eraseToAnyPublisher()
  }
}

public extension Reactive where Base: NSManagedObjectContext {
  private func create<E: Persistable>(_ kind: E.Type = E.self) -> E.T {
    // swiftlint:disable force_cast
    NSEntityDescription.insertNewObject(forEntityName: E.entityName, into: base) as! E.T
    // swiftlint:enable force_cast
  }

  private func get<P: Persistable>(_ persistable: P) throws -> P.T? {
    let fetchRequest: NSFetchRequest<P.T> = NSFetchRequest(entityName: P.entityName)
    fetchRequest.predicate = persistable.predicate()
    // swiftlint:disable force_cast
    let result = try (base.execute(fetchRequest)) as! NSAsynchronousFetchResult<P.T>
    // swiftlint:enable force_cast
    return result.finalResult?.first
  }

  func getSync<P: Persistable>(_ persistable: P) throws -> P.T? {
    let fetchRequest: NSFetchRequest<P.T> = NSFetchRequest(entityName: P.entityName)
    fetchRequest.predicate = persistable.predicate()
    fetchRequest.fetchLimit = 1
    let result = try base.fetch(fetchRequest)
    return result.first
  }

  func delete(_ persistable: some Persistable) throws {
    if let entity = try get(persistable) {
      base.delete(entity)
      try entity.managedObjectContext?.save()
    }
  }

  func entities<P: Persistable>(
    _ kind: P.Type = P.self,
    predicate: NSPredicate? = .none,
    sortDescriptors: [NSSortDescriptor]? = .none,
    fetchLimit: Int? = .none
  ) -> AnyPublisher<[P], Error> {
    let fetchRequest: NSFetchRequest<P.T> = NSFetchRequest(entityName: P.entityName)
    fetchRequest.predicate = predicate
    fetchRequest.sortDescriptors = sortDescriptors ?? [NSSortDescriptor(key: P.primaryAttributeName, ascending: true)]
    if let fetchLimit { fetchRequest.fetchLimit = fetchLimit }
    return entities(fetchRequest: fetchRequest)
      .map { $0.map(P.init) }
      .receive(on: DispatchQueue.main)
      .eraseToAnyPublisher()
  }

  func update<P: Persistable>(_ persistable: P) throws {
    try persistable.update(get(persistable) ?? create(P.self))
  }

  func fetchSync<P: Persistable>(
    _ kind: P.Type = P.self,
    predicate: NSPredicate? = .none,
    sortDescriptors: [NSSortDescriptor]? = .none,
    fetchLimit: Int? = .none
  ) throws -> [P] {
    let fetchRequest: NSFetchRequest<P.T> = NSFetchRequest(entityName: P.entityName)
    fetchRequest.predicate = predicate
    fetchRequest.sortDescriptors = sortDescriptors
    if let fetchLimit {
      fetchRequest.fetchLimit = fetchLimit
    }

    let result = try base.fetch(fetchRequest)
    return result.map { P($0) }
  }

  @discardableResult
  func batchUpdate<P: BatchInsertable>(_ persistables: [P]) throws -> Bool {
    guard !persistables.isEmpty else { return false }
    let entityDesc = NSEntityDescription.entity(forEntityName: P.entityName, in: base)!
    let objects = persistables.map { $0.toDictionary() }
    let request = NSBatchInsertRequest(entity: entityDesc, objects: objects)
    request.resultType = .objectIDs
    base.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    let r = try base.execute(request) as? NSBatchInsertResult
    if let objectIDs = r?.result as? [NSManagedObjectID] {
      let changes = [NSInsertedObjectsKey: objectIDs]
      NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [base])
      try base.save()
      return true
    } else {
      return false
    }
  }

  @discardableResult
  func batchDeleteSync<P: Persistable>(_ persistables: P.Type, predicate: NSPredicate? = .none) throws -> Int? {
    let request = NSFetchRequest<NSFetchRequestResult>(entityName: P.entityName)
    if let predicate {
      request.predicate = predicate
    }
    let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
    deleteRequest.resultType = .resultTypeObjectIDs
    if let result = try base.execute(deleteRequest) as? NSBatchDeleteResult,
      let objectIDs = result.result as? [NSManagedObjectID]
    {
      let changes: [AnyHashable: Any] = [NSDeletedObjectsKey: objectIDs]
      NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [base])
      try base.save()
      return objectIDs.count
    }
    return 0
  }

  @discardableResult
  func batchDelete<P: Persistable & Sendable>(_ persistables: P.Type, predicate: String? = .none) async throws -> Int? {
    try await base.perform {
      let request = NSFetchRequest<NSFetchRequestResult>(entityName: P.entityName)
      if let predicate {
        request.predicate = NSPredicate(format: predicate)
      }
      let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
      deleteRequest.resultType = .resultTypeObjectIDs
      if let result = try base.execute(deleteRequest) as? NSBatchDeleteResult,
        let objectIDs = result.result as? [NSManagedObjectID]
      {
        let changes: [AnyHashable: Any] = [NSDeletedObjectsKey: objectIDs]
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [base])
        try base.save()
        return objectIDs.count
      }
      return 0
    }
  }
}
