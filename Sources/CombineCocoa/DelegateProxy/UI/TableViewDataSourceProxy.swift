#if canImport(UIKit)

import UIKit

let dataSourceNotSet = "DataSource not set"
let delegateNotSet = "Delegate not set"

extension UITableView: HasDataSource {
  public typealias DataSource = UITableViewDataSource
}

@MainActor
private let tableViewDataSourceNotSet = TableViewDataSourceNotSet()

@MainActor
private final class TableViewDataSourceNotSet: NSObject, UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    0
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    exAbstractMethod(message: dataSourceNotSet)
  }
}

@MainActor
open class TableViewDataSourceProxy: DelegateProxy<UITableView, UITableViewDataSource>, DelegateProxyType {
  public weak private(set) var tableView: UITableView?

  public init(tableView: UITableView) {
    self.tableView = tableView
    super.init(parentObject: tableView, delegateProxy: TableViewDataSourceProxy.self)
  }

  public static func registerKnownImplementations() {
    self.register { TableViewDataSourceProxy(tableView: $0) }
  }

  private weak var _requiredMethodsDataSource: UITableViewDataSource? = tableViewDataSourceNotSet

  open override func setForwardToDelegate(_ forwardToDelegate: UITableViewDataSource?, retainDelegate: Bool) {
    _requiredMethodsDataSource = forwardToDelegate ?? tableViewDataSourceNotSet
    super.setForwardToDelegate(forwardToDelegate, retainDelegate: retainDelegate)
  }
}

extension TableViewDataSourceProxy: UITableViewDataSource {
  public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    (_requiredMethodsDataSource ?? tableViewDataSourceNotSet).tableView(tableView, numberOfRowsInSection: section)
  }

  public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    (_requiredMethodsDataSource ?? tableViewDataSourceNotSet).tableView(tableView, cellForRowAt: indexPath)
  }
}

#endif
