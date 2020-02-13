import ReactiveSwift

extension Property {
    public convenience init(initial: Value, then values: () -> Signal<Value, Never>) {
        self.init(initial: initial, then: values())
    }

    public convenience init(initial: Value, then values: () -> SignalProducer<Value, Never>) {
        self.init(initial: initial, then: values())
    }
}

extension Signal {
    public func injectSideEffect(_ next: @escaping (Value) -> Void) -> Signal<Value, Error> {
        return self.on(value: next)
    }

    public func then<Replacement>(_ generator: @autoclosure @escaping () -> Replacement) -> Signal<Replacement.Value, Error> where Replacement: SignalProducerConvertible, Replacement.Error == Error {
        return self
            .take(last: 1)
            .flatMapOnce { _ in generator() }
    }
}

extension SignalProducer {
    /// Used to yield the same input. This is useful in scenarios where there is a possibility of having a transformation (via a flatMap)
    /// but by default, nothing will happen. It makes it much more elegant, than checking for a nil transformation and apply it conditionally
    public static var identity: ((Value) -> SignalProducer<Value, Error>) { return { SignalProducer(value: $0) } }

    /// More explicit call to `on(value: next)`.
    public func injectSideEffect(_ next: @escaping (Value) -> Void) -> SignalProducer<Value, Error> {
        return self.on(value: next)
    }

    public func injectResultSideEffect(_ action: @escaping (Result<Value, Error>) -> Void) -> SignalProducer<Value, Error> {
        return self.on(event: { event in
            switch event {
            case .value(let value): value |> Result.success |> action
            case .failed(let error): error |> Result.failure |> action
            default: break
            }
        })
    }

    /// More explicit call to `on(failure: next)`.
    public func injectFailureSideEffect(_ failed: @escaping (Error) -> Void) -> SignalProducer<Value, Error> {
        return self.on(failed: failed)
    }

    public func injectStartingSideEffect(_ starting: @escaping () -> Void) -> SignalProducer<Value, Error> {
        return self.on(starting: starting)
    }

    public func injectCompletedSideEffect(_ completed: @escaping () -> Void) -> SignalProducer<Value, Error> {
        return self.on(completed: completed)
    }

    public func ignoreError() -> SignalProducer<Value, Never> {
        return self.flatMapError { _ in return SignalProducer<Value, Never>.empty }
    }

    public func ignoreValues() -> SignalProducer<Never, Error> {
        return lift { $0.ignoreValues() }
    }

    public func discardValues() -> SignalProducer<Void, Error> {
        return map { _ in }
    }

    public func bind(to observer: Signal<Value, Error>.Observer) -> SignalProducer<Value, Error> {
        return on(
            failed: observer.send,
            completed: observer.sendCompleted,
            interrupted: observer.sendInterrupted,
            value: observer.send
        )
    }

    public static func run(_ operation: @escaping () -> Value) -> SignalProducer<Value, Error> {
        return SignalProducer {
            return .success(operation())
        }
    }

    public func finally(_ execute: @escaping () -> Void) -> SignalProducer<Value, Error> {
        return on(terminated: execute)
    }
}

extension SignalProducer {
    /// Create a `Signal` from `self`.
    ///
    /// - warning: Be sure that you really need a `Signal`. All events sent
    ///            prior to observations made to the produced `Signal` would be
    ///            lost and irrecoverable.
    ///
    /// - returns: A `Signal` produced by `self`.
    public func makeSignal() -> Signal<Value, Error> {
        var signal: Signal<Value, Error>!
        startWithSignal { inner, _ in signal = inner }
        return signal
    }
}

extension SignalProducer where Value == Never {
    // NOTE: To be removed when migrated to RAS 2.0.
    public func promoteValue<U>() -> SignalProducer<U, Error> {
        return SignalProducer<U, Error> { observer, lifetime in
            lifetime += self.start { event in
                switch event {
                case .value:
                    break
                case let .failed(error):
                    observer.send(error: error)
                case .completed:
                    observer.sendCompleted()
                case .interrupted:
                    observer.sendInterrupted()
                }
            }
        }
    }
}

extension SignalProducer where Value: SignalProducerProtocol, Value.Error == Error {
    fileprivate func once() -> SignalProducer<Value.Value, Value.Error> {
        return lift { $0.once() }
    }
}

extension Signal where Value: SignalProducerProtocol, Value.Error == Error {
    fileprivate func once() -> Signal<Value.Value, Value.Error> {
        return Signal<Value.Value, Value.Error> { observer, lifetime in
            let onceDisposable = SerialDisposable()
            lifetime += onceDisposable

            onceDisposable.inner = self.observe { event in
                switch event {
                case let .value(inner):
                    if !onceDisposable.isDisposed {
                        onceDisposable.dispose()
                        lifetime += inner.producer.start(observer)
                    }

                case let .failed(error):
                    observer.send(error: error)

                case .interrupted:
                    if !onceDisposable.isDisposed {
                        observer.sendInterrupted()
                    }

                case .completed:
                    if !onceDisposable.isDisposed {
                        observer.sendCompleted()
                    }
                }
            }
        }
    }
}

extension Signal {
    public func flatMapLatest<Inner: SignalProducerConvertible>(_ transform: @escaping (Value) -> Inner) -> Signal<Inner.Value, Error> where Inner.Error == Error {
        return self.flatMap(.latest, transform)
    }

    public func flatMapLatest<Inner: SignalProducerConvertible>(_ transform: @escaping (Value) -> Inner) -> Signal<Inner.Value, Error> where Inner.Error == Never {
        return self.flatMap(.latest, transform)
    }

    public func flatMapOnce<Inner: SignalProducerConvertible>(_ transform: @escaping (Value) -> Inner) -> Signal<Inner.Value, Error> where Inner.Error == Error {
        return map { transform($0).producer }.once()
    }

    public func flatMapOnce<Inner: SignalProducerConvertible>(_ transform: @escaping (Value) -> Inner) -> Signal<Inner.Value, Error> where Inner.Error == Never {
        return map { transform($0).producer.promoteError(Error.self) }.once()
    }

    public func replaceError(_ transform: @escaping (Error) -> Value) -> Signal<Value, Never> {
        return flatMapError { SignalProducer<Value, Never> (value: transform($0)) }
    }

    public func replaceError(_ value: Value) -> Signal<Value, Never> {
        return flatMapError { _ in SignalProducer<Value, Never> (value: value) }
    }

    public func ignoreError() -> Signal<Value, Never> {
        return self.flatMapError { _ in return SignalProducer<Value, Never>.empty }
    }
}

extension Signal where Error == Never {
    public func flatMapLatest<Inner: SignalProducerConvertible>(_ transform: @escaping (Value) -> Inner) -> Signal<Inner.Value, Error> where Inner.Error == Never {
        return self.flatMap(.latest, transform)
    }

    public func flatMapLatest<Inner: SignalProducerConvertible>(_ transform: @escaping (Value) -> Inner) -> Signal<Inner.Value, Inner.Error> {
        return self.flatMap(.latest, transform)
    }

    public func flatMapOnce<Inner: SignalProducerConvertible>(_ transform: @escaping (Value) -> Inner) -> Signal<Inner.Value, Error> where Inner.Error == Never {
        return map { transform($0).producer }.once()
    }

    public func flatMapOnce<Inner: SignalProducerConvertible>(_ transform: @escaping (Value) -> Inner) -> Signal<Inner.Value, Inner.Error> {
        return promoteError(Inner.Error.self).flatMapOnce(transform)
    }
}

extension Signal {
    public func combineLatest<U>(with other: U) -> Signal<(Value, U), Error> {
        return map { ($0, other) }
    }
}

extension SignalProducer {
    public func combineLatest<U>(with other: U) -> SignalProducer<(Value, U), Error> {
        return lift { $0.combineLatest(with: other) }
    }
}

extension PropertyProtocol {
    public func flatMapLatest<Inner: PropertyProtocol>(_ transform: @escaping (Value) -> Inner) -> Property<Inner.Value> {
        return self.flatMap(.latest, transform)
    }
}

extension SignalProducer {
    public func flatMapLatest<Inner: SignalProducerConvertible>(_ transform: @escaping (Value) -> Inner) -> SignalProducer<Inner.Value, Error> where Inner.Error == Error {
        return self.flatMap(.latest, transform)
    }

    public func flatMapLatest<Inner: SignalProducerConvertible>(_ transform: @escaping (Value) -> Inner) -> SignalProducer<Inner.Value, Error> where Inner.Error == Never {
        return self.flatMap(.latest, transform)
    }

    public func flatMapOnce<Inner: SignalProducerConvertible>(_ transform: @escaping (Value) -> Inner) -> SignalProducer<Inner.Value, Error> where Inner.Error == Error {
        return map { transform($0).producer }.once()
    }

    public func flatMapOnce<Inner: SignalProducerConvertible>(_ transform: @escaping (Value) -> Inner) -> SignalProducer<Inner.Value, Error> where Inner.Error == Never {
        return map { transform($0).producer.promoteError(Error.self) }.once()
    }

    public func replaceError(_ transform: @escaping (Error) -> Value) -> SignalProducer<Value, Never> {
        return flatMapError { SignalProducer<Value, Never>(value: transform($0)) }
    }

    public func replaceError(_ value: Value) -> SignalProducer<Value, Never> {
        return flatMapError { _ in SignalProducer<Value, Never> (value: value) }
    }
}

extension SignalProducer where Error == Never {
    public func flatMapLatest<Inner: SignalProducerConvertible>(_ transform: @escaping (Value) -> Inner) -> SignalProducer<Inner.Value, Error> where Inner.Error == Never {
        return self.flatMap(.latest, transform)
    }

    public func flatMapLatest<Inner: SignalProducerConvertible>(_ transform: @escaping (Value) -> Inner) -> SignalProducer<Inner.Value, Inner.Error> {
        return self.flatMap(.latest, transform)
    }

    public func flatMapOnce<Inner: SignalProducerConvertible>(_ transform: @escaping (Value) -> Inner) -> SignalProducer<Inner.Value, Error> where Inner.Error == Never {
        return map { transform($0).producer }.once()
    }

    public func flatMapOnce<Inner: SignalProducerConvertible>(_ transform: @escaping (Value) -> Inner) -> SignalProducer<Inner.Value, Inner.Error> {
        return promoteError(Inner.Error.self).flatMapOnce(transform)
    }
}

extension SignalProducer {
    public func whenInterrupted(continueWith producer: SignalProducer<Value, Error>) -> SignalProducer<Value, Error> {
        return materialize()
            .flatMapLatest { event -> SignalProducer<ProducedSignal.Event, Never> in
                switch event {
                case .value, .completed, .failed:
                    return .init(value: event)
                case .interrupted:
                    return producer.materialize()
                }
            }
            .dematerialize()
    }
}

extension SignalProducer {
    public func then<U>(_ replacementGenerator: @escaping () -> SignalProducer<U, Error>) -> SignalProducer<U, Error> {
        return then(SignalProducer<SignalProducer<U, Error>, Error>(replacementGenerator)
            .flatten(.concat))
    }

    public func then<U>(_ replacementGenerator: @escaping () -> SignalProducer<U, Never>) -> SignalProducer<U, Error> {
        return then(SignalProducer<SignalProducer<U, Never>, Never>(replacementGenerator)
            .flatten(.concat)
            .promoteError(Error.self))
    }
}

extension SignalProducer where Error == Never {
    public func then<U, NewError>(_ replacementGenerator: @escaping () -> SignalProducer<U, NewError>) -> SignalProducer<U, NewError> {
        return then(SignalProducer<SignalProducer<U, NewError>, NewError>(replacementGenerator)
            .flatten(.concat))
    }

    public func then<U>(_ replacementGenerator: @escaping () -> SignalProducer<U, Never>) -> SignalProducer<U, Never> {
        return then(SignalProducer<SignalProducer<U, Never>, Never>(replacementGenerator)
            .flatten(.concat))
    }
}

extension SignalProducer {
    public static func value(_ value: Value) -> SignalProducer<Value, Error> {
        return SignalProducer(value: value)
    }

    public static func failed(_ error: Error) -> SignalProducer<Value, Error> {
        return SignalProducer(error: error)
    }
}

extension SignalProducer where Error == Never {
    public static func value(_ value: Value) -> SignalProducer<Value, Error> {
        return SignalProducer(value: value)
    }
}

extension Signal {
    public func discardValues() -> Signal<Void, Error> {
        return map { _ in }
    }

    public func ignoreValues() -> Signal<Never, Error> {
        return Signal<Never, Error> { observer, _ in
            return self.observe { event in
                switch event {
                case .value:
                    break

                case .completed:
                    observer.sendCompleted()

                case let .failed(error):
                    observer.send(error: error)

                case .interrupted:
                    observer.sendInterrupted()
                }
            }
        }
    }
}

extension Signal.Observer {
    public func routingAction(enabledIf condition: Property<Bool>) -> (_ route: Value) -> ReactiveSwift.Action<Void, Void, Never> {
        return { route in
            return ReactiveSwift.Action(enabledIf: condition) { .run { self.send(value: route) } }
        }
    }

    public func routingAction(_ route: Value) -> ReactiveSwift.Action<Void, Void, Never> {
        return ReactiveSwift.Action { .run { self.send(value: route) } }
    }
}

extension Action {
    public func convertToOpaqueAction(_ input: Input) -> Action<Void, Void, Never> {
        return Action<Void, Void, Never>(enabledIf: isEnabled) { _ in
            self.apply(input)
                .map { _ in }
                .flatMapError { _ in .empty }
        }
    }

    public func convertToOpaqueActionWithError(_ input: Input) -> Action<Void, Void, Error> {
        return Action<Void, Void, Error>(enabledIf: isEnabled) { _ in
            self.apply(input)
                .map { _ in }
                .flatMapError { error in
                    switch error {
                    case .disabled:
                        return .empty
                    case .producerFailed(let innerError):
                        return SignalProducer(error: innerError)
                    }
            }
        }
    }
}

extension Signal {
    /// Turns each value into an Optional.
    public func optionalize() -> Signal<Value?, Error> {
        return map(Optional.init)
    }
}

extension SignalProducer {
    /// Turns each value into an Optional.
    public func optionalize() -> SignalProducer<Value?, Error> {
        return lift { $0.optionalize() }
    }
}

extension BindingTargetProvider {
    @discardableResult
    public static func <~
        <Source: BindingSource>
        (provider: Self, source: Source?) -> Disposable?
        where Source.Value == Value {
        guard let source = source else { return nil }

        return source.producer
            .take(during: provider.bindingTarget.lifetime)
            .startWithValues(provider.bindingTarget.action)
    }

    @discardableResult
    public static func <~
        <Source: BindingSource>
        (provider: Self, source: Source?) -> Disposable?
        where Value == Source.Value? {
        guard let source = source else { return nil }

        return provider <~ source.producer.optionalize()
    }
}

extension Signal {
    /// Create a `Signal` which completes whenever `self` sends a value or completes.
    public func makeTrigger() -> Signal<Never, Error> {
        return Signal<Never, Error> { observer, _ in
            return self.observe { event in
                switch event {
                case .value, .completed: observer.sendCompleted()
                case .interrupted:
                    observer.sendInterrupted()
                case let .failed(error):
                    observer.send(error: error)
                }
            }
        }
    }

    public func buffer(until trigger: Signal<Never, Never>) -> Signal<Value, Error> {
        return Signal { observer, _ in
            let state: Atomic<[Value]?> = Atomic([])
            let disposable = CompositeDisposable()

            disposable += trigger.observe { event in
                switch event {
                case .value, .completed, .interrupted:
                    if let innerValues = state.swap(nil) {
                        innerValues.forEach(observer.send(value:))
                    }
                case .failed:
                    break
                }
            }

            disposable += self.observe { event in
                switch event {
                case .value(let value):
                    let shouldSend: Bool = state.modify { buffer in
                        if buffer != nil {
                            buffer!.append(value)
                            return false
                        }
                        return true
                    }

                    if shouldSend {
                        observer.send(value: value)
                    }
                case .completed:
                    observer.sendCompleted()
                case .failed(let error):
                    observer.send(error: error)
                case .interrupted:
                    observer.sendInterrupted()
                }
            }
        }
    }
}

public final class RefreshableProperty<Value, RefreshingError: Swift.Error>: PropertyProtocol {
    private struct State {
        // The upstream producer of the replay is tracking the lifetime of `token`. Disposal or deinitialization of
        // `token` leads to termination of all `replay` consumers.
        let replay: SignalProducer<Never, RefreshingError>
        let token: Lifetime.Token
    }

    fileprivate let box: MutableProperty<Value>
    private let refreshing: MutableProperty<State?>
    public let errors: Signal<RefreshingError, Never>
    private let errorObserver: Signal<RefreshingError, Never>.Observer

    /// The cached value.
    ///
    /// If the latest value is needed, use `latestValues` instead.
    ///
    /// - important: Accessing `value` does not trigger the refresh of the lazy property.
    public var value: Value {
        return box.value
    }

    /// A signal emitting all subsequent values of `self`.
    ///
    /// If the latest value is needed, use `latestValues` instead.
    ///
    /// - important: Accessing `signal` does not trigger the refresh of the lazy property.
    public var signal: Signal<Value, Never> {
        return box.signal
    }


    /// A producer emitting the cached value of `self`, following by all subsquent values
    /// of `self`.
    ///
    /// If the latest value is needed, use `latestValues` instead.
    ///
    /// - important: Accessing `producer` does not trigger the refresh of the lazy
    ///              property.
    public var producer: SignalProducer<Value, Never> {
        return box.producer
    }

    /// A producer that triggers the refresh of the lazy property, and starts forwarding
    /// values of `self` as the refresh completes.
    ///
    /// - note: The returned producer retains `self`.
    public var latestValues: SignalProducer<Value, RefreshingError> {
        return refreshValue.then(producer)
    }

    public var isRefreshing: Property<Bool> {
        return refreshing.map { $0 != nil }
    }

    /// A producer that triggers the refresh of the lazy property.
    ///
    /// - note: The returned producer retains `self`.
    public var refreshValue: SignalProducer<Never, RefreshingError> {
        return SignalProducer { observer, lifetime in
            let state: State = self.refreshing.modify { state in
                if let existingState = state {
                    return existingState
                }

                let (lifetime, token) = Lifetime.make()
                let producer = self.source()
                    .injectSideEffect { [weak self] value in
                        self?.box.value = value
                    }
                    .injectFailureSideEffect { [weak self] value in self?.errorObserver.send(value: value) }
                    // `take(during:)` is applied before `finally` to avoid the value event from being supressed.
                    .take(during: lifetime)
                    .finally {
                        self.refreshing.value = nil
                    }
                    .replayLazily(upTo: 0)

                state = State(replay: producer.ignoreValues(), token: token)
                return state!
            }

            lifetime += state.replay.start(observer)
        }
    }

    private let source: () -> SignalProducer<Value, RefreshingError>

    public init(initial: Value, refreshImmediately: Bool = true, source: @escaping () -> SignalProducer<Value, RefreshingError>) {
        (errors, errorObserver) = Signal.pipe()
        self.box = MutableProperty(initial)
        self.source = source
        self.refreshing = MutableProperty(nil)

        if refreshImmediately {
            refreshValue.start()
        }
    }

    /// Reset the property to `value`.
    ///
    /// - important: `reset(to:)` might be overriden if a consumer starts `refreshValue` concurrently.
    public func reset(to value: Value) {
        refreshing.swap(nil)?.token.dispose()
        box.value = value
    }

    public static func make(_ source: @escaping () -> SignalProducer<Value, RefreshingError>) -> SignalProducer<RefreshableProperty<Value, RefreshingError>, RefreshingError> {
        return source().map { RefreshableProperty(initial: $0, refreshImmediately: false, source: source) }
    }
}

extension RefreshableProperty where Value: OptionalProtocol {
    public func clear() {
        reset(to: Value(reconstructing: nil))
    }
}

extension SignalProducer {
    public func cancel<P: PropertyProtocol>(ifTurningTrue property: P) -> SignalProducer<Value, Error> where P.Value == Bool {
        return SignalProducer { observer, lifetime in
            // `property` must be observed before the event forwarding starts, since
            // `self` must send events synchronously.
            let serialDisposable = SerialDisposable()
            lifetime += serialDisposable
            lifetime += property.producer
                .filter(id)
                .take(first: 1)
                .startWithCompleted {
                    serialDisposable.dispose()
                    observer.sendInterrupted()
            }

            if !serialDisposable.isDisposed {
                serialDisposable.inner = self.start(observer)
            }
        }
    }
}

extension SignalProducer {
    /// Create a producer which flattens a stream of inner producers created by applying
    /// a retry trigger to the given transform. The transform would first be applied when
    /// the producer starts, and subsequently when the retry trigger is invoked.
    ///
    /// - note: If the retry trigger is invoked immediately, it would deadlock.
    ///
    /// - parameters:
    ///   - strategy: The strategy to flatten the inner producers.
    ///   - transform: The transform that creates an inner producer from a retry trigger.
    ///
    /// - returns: A flattened producer of producers created by `transform`.
    public static func retriable(
        _ strategy: FlattenStrategy,
        _ transform: @escaping (_ retry: @escaping () -> Void) -> SignalProducer<Value, Error>
    ) -> SignalProducer<Value, Error> {
        return SignalProducer { observer, lifetime in
            let (feedback, feedbackObserver) = Signal<(), Never>.pipe()
            let retry = { feedbackObserver.send(value: ()) }

            lifetime += SignalProducer<SignalProducer<Value, Error>, Error>(value: transform(retry))
                .concat(SignalProducer<(), Never>(feedback)
                    .map { transform(retry) }
                    .promoteError(Error.self))
                .flatten(strategy)
                .start(observer)
        }
    }
}

extension PropertyProtocol where Value == Bool {
    public prefix static func !(_ property: Self) -> Property<Bool> {
        return property.negate()
    }
}

public final class ActionInput<Input>: BindingTargetProvider {
    // `ActionInput` holds a strong reference so that it can be used as a view to an
    // unretained `Action`.
    private let action: AnyObject?

    public let isEnabled: Property<Bool>
    public let isExecuting: Property<Bool>
    public let bindingTarget: BindingTarget<Input>

    public init<Output, Error>(_ action: Action<Input, Output, Error>) {
        self.action = action

        isEnabled = action.isEnabled
        isExecuting = action.isExecuting
        bindingTarget = action.bindingTarget
    }

    public init(
        isEnabled: Property<Bool>,
        isExecuting: Property<Bool>,
        bindingTarget: BindingTarget<Input>
    ) {
        self.action = nil
        self.isEnabled = isEnabled
        self.isExecuting = isExecuting
        self.bindingTarget = bindingTarget
    }
}

// NOTE: This should be included in the next major version of ReactiveSwift
// Reference: https://github.com/ReactiveCocoa/ReactiveSwift/pull/611
extension Signal {
    public func withLatest<Samplee: SignalProducerConvertible>(from samplee: Samplee) -> Signal<(Value, Samplee.Value), Error> where Samplee.Error == Never {
        return Signal<(Value, Samplee.Value), Error> { observer, lifetime in
            samplee.producer.startWithSignal { signal, disposable in
                lifetime += disposable
                lifetime += self.withLatest(from: signal).observe(observer)
            }
        }
    }
}

extension Property {
    public func observe(on scheduler: Scheduler) -> Property<Value> {
        // NOTE: This is not a contractually correct implementation since it
        //       repeats the initial value twice, but it does the job.
        return Property(
            initial: value,
            then: producer.observe(on: scheduler)
        )
    }
}

// MARK: - delayError

extension Signal {
    /// Delays error only.
    public func delayError(interval: TimeInterval, on scheduler: DateScheduler) -> Signal<Value, Error> {
        return materializeResults()
            .flatMap(.merge) { result -> SignalProducer<Value, Error> in
                switch result {
                case let .success(value):
                    return SignalProducer(value: value)
                case let .failure(error):
                    return SignalProducer(value: error)
                        .delay(interval, on: scheduler)
                        .attemptMap(Result.failure)
                }
        }
    }
}

extension SignalProducer {
    /// Delays error only.
    public func delayError(interval: TimeInterval, on scheduler: DateScheduler) -> SignalProducer<Value, Error> {
        return lift { $0.delayError(interval: interval, on: scheduler) }
    }
}
