#if canImport(UIKit)

import UIKit

open class TableViewDelegateProxy: ScrollViewDelegateProxy {
  public weak private(set) var tableView: UITableView?

  public init(tableView: UITableView) {
    self.tableView = tableView
    super.init(scrollView: tableView)
  }
}

extension TableViewDelegateProxy: UITableViewDelegate {}

#endif
