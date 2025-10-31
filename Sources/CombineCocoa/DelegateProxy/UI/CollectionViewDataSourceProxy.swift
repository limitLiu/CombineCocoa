#if canImport(UIKit)

import UIKit

extension UICollectionView: HasDataSource {
  public typealias DataSource = UICollectionViewDataSource
}

@MainActor
private let collectionViewDataSourceNotSet = CollectionViewDataSourceNotSet()

@MainActor
private final class CollectionViewDataSourceNotSet: NSObject, UICollectionViewDataSource {
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    0
  }

  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    exAbstractMethod(message: dataSourceNotSet)
  }
}

@MainActor
open class CollectionViewDataSourceProxy: DelegateProxy<UICollectionView, UICollectionViewDataSource>,
  @preconcurrency DelegateProxyType
{

  public weak private(set) var collectionView: UICollectionView?

  public init(collectionView: UICollectionView) {
    self.collectionView = collectionView
    super.init(parentObject: collectionView, delegateProxy: CollectionViewDataSourceProxy.self)
  }

  public static func registerKnownImplementations() {
    self.register { CollectionViewDataSourceProxy(collectionView: $0) }
  }

  private weak var _requiredMethodsDataSource: UICollectionViewDataSource? = collectionViewDataSourceNotSet

  open override func setForwardToDelegate(_ forwardToDelegate: UICollectionViewDataSource?, retainDelegate: Bool) {
    _requiredMethodsDataSource = forwardToDelegate ?? collectionViewDataSourceNotSet
    super.setForwardToDelegate(forwardToDelegate, retainDelegate: retainDelegate)
  }
}

extension CollectionViewDataSourceProxy: UICollectionViewDataSource {
  public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    (_requiredMethodsDataSource ?? collectionViewDataSourceNotSet).collectionView(
      collectionView,
      numberOfItemsInSection: section
    )
  }

  public func collectionView(
    _ collectionView: UICollectionView,
    cellForItemAt indexPath: IndexPath
  ) -> UICollectionViewCell {
    (_requiredMethodsDataSource ?? collectionViewDataSourceNotSet).collectionView(
      collectionView,
      cellForItemAt: indexPath
    )
  }
}

#endif
