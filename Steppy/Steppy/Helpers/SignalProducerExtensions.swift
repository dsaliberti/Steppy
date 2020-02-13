import ReactiveFeedback
import ReactiveSwift

extension SignalProducerProtocol {
    func retry<R>(
        scheduler: Scheduler,
        when: @escaping (Error) -> SignalProducer<R, Error>,
        retry: @escaping () -> SignalProducer<Value, Error>
    ) -> SignalProducer<Value, Error> {
        return RetrySystem(
            source: producer,
            scheduler: scheduler,
            when: when,
            retry: retry
        ).producer
    }
}

final class RetrySystem<T, V, Error: Swift.Error> {
    let producer: SignalProducer<T, Error>

    init(
        source: SignalProducer<T, Error>,
        scheduler: Scheduler,
        when: @escaping (Error) -> SignalProducer<V, Error>,
        retry: @escaping () -> SignalProducer<T, Error>
    ) {
        producer = SignalProducer.system(
            initial: State.empty,
            scheduler: scheduler,
            reduce: RetrySystem.reduce,
            feedbacks: [
                RetrySystem.whenInitialRunIsActive(source: source),
                RetrySystem.whenError(when: when),
                RetrySystem.whenRetrying(retry: retry)
            ]
        )
        .filterMap { (state) -> Signal<T, Error>.Event? in
            switch state {
            case let .value(value), let .valueFromRetry(value):
                return .value(value)
            case let .retryFailed(error):
                return .failed(error)
            default:
                return nil
            }
        }
        .dematerialize()
    }

    private enum State {
        case empty
        case value(T)
        case error(Error)
        case retrying
        case valueFromRetry(T)
        case retryFailed(Error)

        var isInitialRunActive: Bool {
            switch self {
            case .empty, .value:
                return true
            default:
                return false
            }
        }

        var isRetrying: Bool {
            switch self {
            case .retrying, .valueFromRetry:
                return true
            default:
                return false
            }
        }
    }

    enum Event {
        case terminate(Error)
        case didFail(Error)
        case didGetValue(T)
        case didGetValueFromRetry(T)
        case shouldRetry
    }

    private static func whenInitialRunIsActive(source: SignalProducer<T, Error>) -> Feedback<State, Event> {
        return Feedback(skippingRepeated: ^\.isInitialRunActive) { shouldBegin -> SignalProducer<Event, Never> in
            guard shouldBegin else { return .empty }

            return source.map(Event.didGetValue)
                .replaceError(Event.didFail)
        }
    }

    private static func whenError(
        when: @escaping (Error) -> SignalProducer<V, Error>
    ) -> Feedback<State, Event> {
        return Feedback { state -> SignalProducer<Event, Never> in
            guard case let .error(error) = state else { return .empty }

            return when(error)
                .map { _ in Event.shouldRetry }
                .replaceError(Event.terminate)
        }
    }

    private static func whenRetrying(
        retry: @escaping () -> SignalProducer<T, Error>
    ) -> Feedback<State, Event> {
        return Feedback(skippingRepeated: ^\.isRetrying) { shouldBegin -> SignalProducer<Event, Never> in
            guard shouldBegin else { return .empty }

            return retry()
                .map(Event.didGetValueFromRetry)
                .replaceError(Event.didFail)
        }
    }

    private static func reduce(state: State, event: Event) -> State {
        switch event {
        case let .didGetValue(value):
            return .value(value)
        case let .didGetValueFromRetry(value):
            return .valueFromRetry(value)
        case let .didFail(error):
            return .error(error)
        case .shouldRetry:
            return .retrying
        case let .terminate(error):
            return .retryFailed(error)
        }
    }
}
