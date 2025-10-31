import Combine
import CoreData

@globalActor actor CoreData {
  static let shared = CoreData()
  private init() {}
}

public nonisolated protocol Persistable {
  associatedtype T: NSManagedObject
  static var entityName: String { get }
  static var primaryAttributeName: String { get }
  var identity: String { get }

  init(_ entity: T)

  func update(_ entity: T)

  func predicate() -> NSPredicate
}

public nonisolated protocol BatchInsertable: Persistable {
  func toDictionary() -> [String: Any]
}

public nonisolated extension Persistable {
  func predicate() -> NSPredicate {
    NSPredicate(format: "%K = %@", Self.primaryAttributeName, identity)
  }
}
