#if canImport(UIKit)

public nonisolated protocol SectionModelType: Hashable, Sendable where Item: Hashable & Sendable {
  associatedtype Item
  var items: [Item] { get }
  init(original: Self, items: [Item])
}

public nonisolated struct SectionModel<Section: Sendable & Hashable, ItemType: Sendable & Hashable> {
  public var model: Section
  public var items: [Item]

  public init(model: Section, items: [Item]) {
    self.model = model
    self.items = items
  }
}

extension SectionModel: SectionModelType {
  public typealias Identity = Section
  public typealias Item = ItemType

  public var identity: Section {
    return model
  }
}

extension SectionModel: CustomStringConvertible {
  public var description: String {
    return "\(self.model) > \(items)"
  }
}

extension SectionModel {
  public init(original: SectionModel<Section, Item>, items: [Item]) {
    self.model = original.model
    self.items = items
  }
}

extension SectionModel: Equatable where Section: Equatable, ItemType: Equatable {

  public static func == (lhs: SectionModel, rhs: SectionModel) -> Bool {
    return lhs.model == rhs.model
      && lhs.items == rhs.items
  }
}

#endif
