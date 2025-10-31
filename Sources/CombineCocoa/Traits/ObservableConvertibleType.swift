#if canImport(Combine)
import Combine

public protocol ObservableConvertibleType {
  associatedtype Element
  func asObservable() -> Observable<Element>
}

#endif
