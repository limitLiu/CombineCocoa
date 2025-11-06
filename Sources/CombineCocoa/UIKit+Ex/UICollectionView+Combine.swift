#if canImport(UIKit)

import Combine
import class Foundation.NSObject
import struct Foundation.IndexPath
import class UIKit.UICollectionView
import class UIKit.UICollectionViewCell
import protocol UIKit.UICollectionViewDataSource
import protocol UIKit.UICollectionViewDelegate

extension UICollectionView: CombineCompatible {}

@MainActor
public protocol CombineCollectionViewDataSourceType {
  associatedtype Element
  func collectionView(_ collectionView: UICollectionView, observedEvent: Event<Element>)
}

class _CollectionViewCombineArrayDataSource: NSObject, UICollectionViewDataSource {
  func _collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    0
  }

  @objc(numberOfSectionsInCollectionView:)
  func numberOfSections(in: UICollectionView) -> Int {
    1
  }

  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    _collectionView(collectionView, numberOfItemsInSection: section)
  }

  fileprivate func _collectionView(
    _ collectionView: UICollectionView,
    cellForItemAt indexPath: IndexPath
  ) -> UICollectionViewCell {
    exAbstractMethod()
  }

  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    _collectionView(collectionView, cellForItemAt: indexPath)
  }
}

class CollectionViewCombineArrayDataSource<Element>: _CollectionViewCombineArrayDataSource, SectionedViewDataSourceType
{
  typealias CellFactory = (UICollectionView, Int, Element) -> UICollectionViewCell
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

  override func _collectionView(
    _ collectionView: UICollectionView,
    cellForItemAt indexPath: IndexPath
  ) -> UICollectionViewCell {
    cellFactory(collectionView, indexPath.item, itemModels![indexPath.item])
  }

  override func _collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    itemModels?.count ?? 0
  }

  func collectionView(_ collectionView: UICollectionView, observedElements: [Element]) {
    self.itemModels = observedElements
    collectionView.reloadData()
    collectionView.collectionViewLayout.invalidateLayout()
  }
}

@MainActor
final class CollectionViewCombineArrayDataSourceSequenceWrapper<Sequence: Swift.Sequence>:
  CollectionViewCombineArrayDataSource<Sequence.Element>, CombineCollectionViewDataSourceType
{
  typealias Element = Sequence

  override init(cellFactory: @escaping CellFactory) {
    super.init(cellFactory: cellFactory)
  }

  func collectionView(_ collectionView: UICollectionView, observedEvent: Event<Sequence>) {
    Binder(self) { dataSource, sectionModels in
      dataSource.collectionView(collectionView, observedElements: Array(sectionModels))
    }
    .on(observedEvent)
  }
}

extension Reactive where Base: UICollectionView {
  @MainActor
  public func items<Sequence: Swift.Sequence, Source: Publisher>(
    _ source: Source
  )
    -> (_ cellFactory: @escaping (UICollectionView, Int, Sequence.Element) -> UICollectionViewCell)
    -> AnyCancellable
  where Source.Output == Sequence {
    return { cellFactory in
      let dataSource = CollectionViewCombineArrayDataSourceSequenceWrapper<Sequence>(cellFactory: cellFactory)
      return self.items(dataSource: dataSource)(source)
    }
  }

  @MainActor
  public func items<Sequence: Swift.Sequence, Cell: UICollectionViewCell, Source: Publisher>(
    cellIdentifier: String,
    cellType: Cell.Type = Cell.self
  )
    -> (_ source: Source)
    -> (_ configureCell: @escaping (Int, Sequence.Element, Cell) -> Void)
    -> AnyCancellable where Source.Output == Sequence
  {
    { source in
      { configureCell in
        let dataSource = CollectionViewCombineArrayDataSourceSequenceWrapper<Sequence> { cv, i, item in
          let indexPath = IndexPath(item: i, section: 0)
          // swiftlint:disable force_cast
          let cell = cv.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as! Cell
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
    DataSource: CombineCollectionViewDataSourceType & UICollectionViewDataSource,
    Source: Publisher
  >(
    dataSource: DataSource
  )
    -> (_ source: Source)
    -> AnyCancellable where DataSource.Element == Source.Output
  {
    { source in
      _ = self.delegate
      return
        source
        .subscribeProxyDataSource(ofObject: base, dataSource: dataSource, retainDataSource: true) {
          [weak collectionView = base] (_: CollectionViewDataSourceProxy, event) in
          guard let collectionView else { return }
          dataSource.collectionView(collectionView, observedEvent: event)
        }
    }
  }
}

extension Reactive where Base: UICollectionView {
  @MainActor
  public func setDataSource(_ dataSouce: UICollectionViewDataSource) -> AnyCancellable {
    CollectionViewDataSourceProxy.installForwardDelegate(
      dataSouce,
      retainDelegate: false,
      onProxyForObject: base
    )
  }

  @MainActor
  public var itemSelected: ControlEvent<IndexPath> {
    let source = self.delegate.methodInvoked(#selector(UICollectionViewDelegate.collectionView(_:didSelectItemAt:)))
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
          return Just(try view.rx.model(at: indexPath)).eraseToAnyPublisher()
        } catch {
          return Empty<T, Never>().eraseToAnyPublisher()
        }
      }
      .eraseToAnyPublisher()
    return ControlEvent(events: source)
  }

  @MainActor
  public var dataSource: DelegateProxy<UICollectionView, UICollectionViewDataSource> {
    CollectionViewDataSourceProxy.proxy(for: base)
  }

  @MainActor
  public func model<T>(at indexPath: IndexPath) throws -> T {
    let dataSource: SectionedViewDataSourceType = castOrFatalError(
      self.dataSource.forwardToDelegate(),
      message: "This method only works in case one of the `rx.items*` methods was used."
    )
    let element = try dataSource.model(at: indexPath)
    return try castOrThrow(T.self, element)
  }
}

#endif
