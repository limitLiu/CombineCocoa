#if canImport(UIKit)

import Combine
import class Foundation.RunLoop
import class Foundation.NSObject
import struct Foundation.IndexPath
import class Foundation.NSNumber
import class UIKit.UIView
import class UIKit.UITableView
import class UIKit.UITableViewCell
import protocol UIKit.UITableViewDataSource
import protocol UIKit.UITableViewDelegate

extension UITableView: CombineCompatible {}

@MainActor
public protocol CombineTableViewDataSourceType {
  associatedtype Element
  func tableView(_ tableView: UITableView, observedEvent: Event<Element>)
}

public nonisolated protocol SectionedViewDataSourceType {
  func model(at indexPath: IndexPath) throws -> Any
}

class _TableViewCombineArrayDataSource: NSObject, UITableViewDataSource {
  func numberOfSections(in tableView: UITableView) -> Int {
    1
  }

  func _tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    0
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    _tableView(tableView, numberOfRowsInSection: section)
  }

  func _tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    exAbstractMethod()
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    _tableView(tableView, cellForRowAt: indexPath)
  }
}

class TableViewCombineArrayDataSource<Element>: _TableViewCombineArrayDataSource, SectionedViewDataSourceType {
  typealias CellFactory = (UITableView, Int, Element) -> UITableViewCell
  var itemModels: [Element]?

  init(cellFactory: @escaping CellFactory) {
    self.cellFactory = cellFactory
  }

  func modelAtIndex(_ index: Int) -> Element? {
    itemModels?[index]
  }

  func model(at indexPath: IndexPath) throws -> Any {
    precondition(indexPath.section == 0)
    guard let item = itemModels?[indexPath.item] else {
      throw ExCocoaError.itemsNotYetBound(object: self)
    }
    return item
  }

  let cellFactory: CellFactory

  override func _tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    cellFactory(tableView, indexPath.item, itemModels![indexPath.row])
  }

  override func _tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    itemModels?.count ?? 0
  }

  func tableView(_ tableView: UITableView, observedElements: [Element]) {
    self.itemModels = observedElements
    tableView.reloadData()
  }
}

@MainActor
final class TableViewCombineArrayDataSourceSequenceWrapper<Sequence: Swift.Sequence>: TableViewCombineArrayDataSource<
  Sequence.Element
>, CombineTableViewDataSourceType
{
  typealias Element = Sequence

  override init(cellFactory: @escaping CellFactory) {
    super.init(cellFactory: cellFactory)
  }

  func tableView(_ tableView: UITableView, observedEvent: Event<Sequence>) {
    Binder(self) { dataSource, sectionModels in
      dataSource.tableView(tableView, observedElements: Array(sectionModels))
    }
    .on(observedEvent)
  }
}

extension Reactive where Base: UITableView {
  @MainActor
  public func items<Sequence: Swift.Sequence, Source: Publisher>(
    _ source: Source
  )
    -> (_ cellFactory: @escaping (UITableView, Int, Sequence.Element) -> UITableViewCell)
    -> AnyCancellable
  where Source.Output == Sequence {
    return { cellFactory in
      let dataSource = TableViewCombineArrayDataSourceSequenceWrapper<Sequence>(cellFactory: cellFactory)
      return self.items(dataSource: dataSource)(source)
    }
  }

  @MainActor
  public func items<Sequence: Swift.Sequence, Cell: UITableViewCell, Source: Publisher>(
    cellIdentifier: String,
    cellType: Cell.Type = Cell.self
  )
    -> (_ source: Source)
    -> (_ configureCell: @escaping (Int, Sequence.Element, Cell) -> Void)
    -> AnyCancellable
  where Source.Output == Sequence {
    return { source in
      return { configureCell in
        let dataSource = TableViewCombineArrayDataSourceSequenceWrapper<Sequence> { tv, i, item in
          let indexPath = IndexPath(item: i, section: 0)
          // swiftlint:disable force_cast
          let cell = tv.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! Cell
          // swiftlint:enable force_cast
          configureCell(i, item, cell)
          return cell
        }
        return self.items(dataSource: dataSource)(source)
      }
    }
  }

  @MainActor
  public func items<
    DataSource: CombineTableViewDataSourceType & UITableViewDataSource,
    Source: Publisher
  >(
    dataSource: DataSource
  )
    -> (_ source: Source)
    -> AnyCancellable
  where DataSource.Element == Source.Output {
    return { source in
      _ = self.delegate
      return source.subscribeProxyDataSource(ofObject: base, dataSource: dataSource, retainDataSource: true) {
        [weak tableView = base] (_: TableViewDataSourceProxy, event) in
        guard let tableView else { return }
        dataSource.tableView(tableView, observedEvent: event)
      }
    }
  }
}

extension Publisher {
  @MainActor
  func subscribeProxyDataSource<DelegateProxy: DelegateProxyType>(
    ofObject object: DelegateProxy.ParentObject,
    dataSource: DelegateProxy.Delegate,
    retainDataSource: Bool,
    binding: @escaping (DelegateProxy, Event<Output>) -> Void
  )
    -> AnyCancellable
  where DelegateProxy.ParentObject: UIView, DelegateProxy.Delegate: AnyObject {
    let proxy = DelegateProxy.proxy(for: object)
    let unregisterDelegate = DelegateProxy.installForwardDelegate(
      dataSource,
      retainDelegate: retainDataSource,
      onProxyForObject: object
    )

    if object.window != nil {
      object.layoutIfNeeded()
    }

    let subscription = self.receive(on: RunLoop.main)
      .prefix(untilOutputFrom: object.rx.deallocated)
      .sink(
        receiveCompletion: { event in
          switch event {
          case .finished:
            binding(proxy, .completed)
            unregisterDelegate.cancel()
          case .failure(let e):
            bindingError(e)
            unregisterDelegate.cancel()
          }
        },
        receiveValue: { [weak object] value in
          if let object {
            assert(
              proxy === DelegateProxy.currentDelegate(for: object),
              "Proxy changed from the time it was first set.\nOriginal: \(proxy)\nExisting: \(String(describing: DelegateProxy.currentDelegate(for: object)))"
            )
          }
          binding(proxy, .next(value))
        }
      )
    return AnyCancellable { [weak object] in
      subscription.cancel()
      if object?.window != nil {
        object?.layoutIfNeeded()
      }
      unregisterDelegate.cancel()
    }
  }
}

extension Reactive where Base: UITableView {
  @MainActor
  public var dataSource: DelegateProxy<UITableView, UITableViewDataSource> {
    TableViewDataSourceProxy.proxy(for: base)
  }

  @MainActor
  public func setDataSource(_ dataSouce: UITableViewDataSource) -> AnyCancellable {
    TableViewDataSourceProxy.installForwardDelegate(
      dataSouce,
      retainDelegate: false,
      onProxyForObject: base
    )
  }

  @MainActor
  public var itemSelected: ControlEvent<IndexPath> {
    let source = self.delegate.methodInvoked(#selector(UITableViewDelegate.tableView(_:didSelectRowAt:)))
      .tryMap { a in try castOrThrow(IndexPath.self, a[1]) }
      .catch { error -> Empty<IndexPath, Never> in
        debugPrint("cathed error:", error)
        return Empty()
      }
    return ControlEvent(events: source)
  }

  @MainActor
  public func modelSelected<T>(_ modelType: T.Type) -> ControlEvent<T> {
    let source: Observable<T> = self.itemSelected
      .flatMap { [weak view = base] indexPath -> Observable<T> in
        guard let view else {
          return Empty<T, Never>().eraseToAnyPublisher()
        }
        do {
          let model: T = try view.rx.model(at: indexPath)
          return Just(model).eraseToAnyPublisher()
        } catch {
          return Empty<T, Never>().eraseToAnyPublisher()
        }
      }
      .eraseToAnyPublisher()
    return ControlEvent(events: source)
  }

  @MainActor
  public func model<T>(at indexPath: IndexPath) throws -> T {
    let dataSource: SectionedViewDataSourceType = castOrFatalError(
      self.dataSource.forwardToDelegate(),
      message: "This method only works in case one of the `rx.items*` methods was used."
    )
    let element = try dataSource.model(at: indexPath)
    return castOrFatalError(element)
  }

  @MainActor
  public var itemDeleted: ControlEvent<IndexPath> {
    let source = self.dataSource.methodInvoked(#selector(UITableViewDataSource.tableView(_:commit:forRowAt:)))
      .tryFilter { a in
        UITableViewCell.EditingStyle(rawValue: (try castOrThrow(NSNumber.self, a[1])).intValue) == .delete
      }
      .tryMap { a in
        try castOrThrow(IndexPath.self, a[2])
      }
      .catch { error -> Empty<IndexPath, Never> in
        debugPrint("cathed error:", error)
        return Empty()
      }
    return ControlEvent(events: source)
  }

  @MainActor
  public func modelDeleted<T>(_ modelType: T.Type) -> ControlEvent<T> {
    let source: Observable<T> = self.itemDeleted
      .flatMap { [weak view = base] indexPath -> Observable<T> in
        guard let view else {
          return Empty<T, Never>().eraseToAnyPublisher()
        }
        do {
          let model: T = try view.rx.model(at: indexPath)
          return Just(model).eraseToAnyPublisher()
        } catch {
          return Empty<T, Never>().eraseToAnyPublisher()
        }
      }
      .eraseToAnyPublisher()
    return ControlEvent(events: source)
  }
}

#endif
