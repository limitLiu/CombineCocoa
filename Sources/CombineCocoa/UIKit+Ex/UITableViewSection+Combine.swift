#if canImport(UIKit) && os(iOS)

import Combine
import class Foundation.NSObject
import struct Foundation.IndexPath
import class UIKit.UITableView
import class UIKit.UITableViewCell
import protocol UIKit.UITableViewDataSource

open class TableViewSectionedDataSource<Section: SectionModelType>: NSObject, UITableViewDataSource,
  SectionedViewDataSourceType
{
  public typealias Item = Section.Item
  public typealias ConfigureCell = (TableViewSectionedDataSource<Section>, UITableView, IndexPath, Item) ->
    UITableViewCell
  public typealias TitleForHeaderInSection = (TableViewSectionedDataSource<Section>, Int) -> String?
  public typealias TitleForFooterInSection = (TableViewSectionedDataSource<Section>, Int) -> String?
  public typealias CanEditRowAtIndexPath = (TableViewSectionedDataSource<Section>, IndexPath) -> Bool
  public typealias CanMoveRowAtIndexPath = (TableViewSectionedDataSource<Section>, IndexPath) -> Bool

  public typealias SectionIndexTitles = (TableViewSectionedDataSource<Section>) -> [String]?
  public typealias SectionForSectionIndexTitle = (TableViewSectionedDataSource<Section>, _ title: String, _ index: Int)
    -> Int

  public init(
    configureCell: @escaping ConfigureCell,
    titleForHeaderInSection: @escaping TitleForHeaderInSection = { _, _ in nil },
    titleForFooterInSection: @escaping TitleForFooterInSection = { _, _ in nil },
    canEditRowAtIndexPath: @escaping CanEditRowAtIndexPath = { _, _ in true },
    canMoveRowAtIndexPath: @escaping CanMoveRowAtIndexPath = { _, _ in true },
    sectionIndexTitles: @escaping SectionIndexTitles = { _ in nil },
    sectionForSectionIndexTitle: @escaping SectionForSectionIndexTitle = { _, _, index in index }
  ) {
    self.configureCell = configureCell
    self.titleForHeaderInSection = titleForHeaderInSection
    self.titleForFooterInSection = titleForFooterInSection
    self.canEditRowAtIndexPath = canEditRowAtIndexPath
    self.canMoveRowAtIndexPath = canMoveRowAtIndexPath
    self.sectionIndexTitles = sectionIndexTitles
    self.sectionForSectionIndexTitle = sectionForSectionIndexTitle
  }
  #if DEBUG
  var _dataSourceBound: Bool = false

  private func ensureNotMutatedAfterBinding() {
    assert(
      !_dataSourceBound,
      """
      Data source is already bound. Please write this line before binding call (`bindTo`, `drive`).
      Data source must first be completely configured, and then bound after that, otherwise there could be runtime bugs, glitches, or partial malfunctions.
      """
    )
  }
  #endif
  public typealias SectionModelSnapshot = SectionModel<Section, Item>

  private var _sectionModels: [SectionModelSnapshot] = []

  open var sectionModels: [Section] {
    return _sectionModels.map { Section(original: $0.model, items: $0.items) }
  }

  open subscript(section: Int) -> Section {
    let sectionModel = self._sectionModels[section]
    return Section(original: sectionModel.model, items: sectionModel.items)
  }

  open subscript(indexPath: IndexPath) -> Item {
    get {
      return self._sectionModels[indexPath.section].items[indexPath.item]
    }
    set(item) {
      var section = self._sectionModels[indexPath.section]
      section.items[indexPath.item] = item
      self._sectionModels[indexPath.section] = section
    }
  }

  open func model(at indexPath: IndexPath) throws -> Any {
    guard indexPath.section < self._sectionModels.count,
      indexPath.item < self._sectionModels[indexPath.section].items.count
    else {
      throw ExCocoaError.itemsNotYetBound(object: indexPath)
    }

    return self[indexPath]
  }

  open func setSections(_ sections: [Section]) {
    self._sectionModels = sections.map { SectionModelSnapshot(model: $0, items: $0.items) }
  }

  open var configureCell: ConfigureCell {
    didSet {
      #if DEBUG
      ensureNotMutatedAfterBinding()
      #endif
    }
  }

  open var titleForHeaderInSection: TitleForHeaderInSection {
    didSet {
      #if DEBUG
      ensureNotMutatedAfterBinding()
      #endif
    }
  }
  open var titleForFooterInSection: TitleForFooterInSection {
    didSet {
      #if DEBUG
      ensureNotMutatedAfterBinding()
      #endif
    }
  }

  open var canEditRowAtIndexPath: CanEditRowAtIndexPath {
    didSet {
      #if DEBUG
      ensureNotMutatedAfterBinding()
      #endif
    }
  }
  open var canMoveRowAtIndexPath: CanMoveRowAtIndexPath {
    didSet {
      #if DEBUG
      ensureNotMutatedAfterBinding()
      #endif
    }
  }

  #if os(iOS)
  open var sectionIndexTitles: SectionIndexTitles {
    didSet {
      #if DEBUG
      ensureNotMutatedAfterBinding()
      #endif
    }
  }
  open var sectionForSectionIndexTitle: SectionForSectionIndexTitle {
    didSet {
      #if DEBUG
      ensureNotMutatedAfterBinding()
      #endif
    }
  }
  #endif

  // MARK: - UITableViewDataSource

  open func numberOfSections(in tableView: UITableView) -> Int {
    return _sectionModels.count
  }

  open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    guard _sectionModels.count > section else { return 0 }
    return _sectionModels[section].items.count
  }

  open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    precondition(indexPath.item < _sectionModels[indexPath.section].items.count)

    return configureCell(self, tableView, indexPath, self[indexPath])
  }

  open func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    return titleForHeaderInSection(self, section)
  }

  open func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
    return titleForFooterInSection(self, section)
  }

  open func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return canEditRowAtIndexPath(self, indexPath)
  }

  open func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    return canMoveRowAtIndexPath(self, indexPath)
  }

  open func tableView(
    _ tableView: UITableView,
    moveRowAt sourceIndexPath: IndexPath,
    to destinationIndexPath: IndexPath
  ) {
    self._sectionModels.moveFromSourceIndexPath(sourceIndexPath, destinationIndexPath: destinationIndexPath)
  }

  open func sectionIndexTitles(for tableView: UITableView) -> [String]? {
    return sectionIndexTitles(self)
  }

  open func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
    return sectionForSectionIndexTitle(self, title, index)
  }
}

@MainActor
open class TableViewSectionedDiffableDataSource<Section: SectionModelType>: TableViewSectionedDataSource<Section>,
  CombineTableViewDataSourceType
{
  public typealias Element = [Section]

  open func tableView(_ tableView: UITableView, observedEvent: Event<Element>) {
    Binder(self) { dataSource, element in
      #if DEBUG
      dataSource._dataSourceBound = true
      #endif
      dataSource.setSections(element)
      tableView.reloadData()
    }.on(observedEvent)
  }
}

extension Array where Element: SectionModelType {
  mutating func moveFromSourceIndexPath(_ sourceIndexPath: IndexPath, destinationIndexPath: IndexPath) {
    let sourceSection = self[sourceIndexPath.section]
    var sourceItems = sourceSection.items

    let sourceItem = sourceItems.remove(at: sourceIndexPath.item)

    let sourceSectionNew = Element(original: sourceSection, items: sourceItems)
    self[sourceIndexPath.section] = sourceSectionNew

    let destinationSection = self[destinationIndexPath.section]
    var destinationItems = destinationSection.items
    destinationItems.insert(sourceItem, at: destinationIndexPath.item)

    self[destinationIndexPath.section] = Element(original: destinationSection, items: destinationItems)
  }
}

#endif
