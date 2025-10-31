public typealias Observable<T> = AnyPublisher<T, Never>
public typealias BehaviorRelay<T> = CurrentValueSubject<T, Never>
public typealias PublishRelay<T> = PublishSubject<T, Never>
