#if canImport(UIKit)

import UIKit

open class CollectionViewDelegateProxy: ScrollViewDelegateProxy {
  public weak private(set) var collectionView: UICollectionView?

  public init(collectionView: UICollectionView) {
    self.collectionView = collectionView
    super.init(scrollView: collectionView)
  }
}

extension CollectionViewDelegateProxy: UICollectionViewDelegate {}

#endif
