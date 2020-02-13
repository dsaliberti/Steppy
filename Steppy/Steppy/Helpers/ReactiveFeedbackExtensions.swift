import ReactiveSwift
import ReactiveFeedback

extension Feedback {
    public typealias InputSubmitter = (Event) -> SignalProducer<Never, Never>

    public static func pipe(on scheduler: Scheduler) -> (output: Feedback<State, Event>, input: InputSubmitter) {
        let (output, input) = Signal<Event, Never>.pipe()

        return (
            output: self.init { innerScheduler, _ in
                precondition(
                    scheduler === innerScheduler,
                    "Feedback pipe is created with a different scheduler than the one used by the feedback loop."
                )
                return output.observe(on: scheduler)
            },
            input: { event -> SignalProducer<Never, Never> in
                // The returned producer would complete on `scheduler`, so as to
                // ensure that any subsequent work would always execute after the
                // request feedback has been consumed by the feedback loop.
                return SignalProducer.empty
                    .start(on: scheduler)
                    .on(starting: { input.send(value: event) })
            }
        )
    }

    public static func input() -> (feedback: Feedback<State, Event>, observer: (Event) -> Void) {
        let pipe = Signal<Event, Never>.pipe()
        let feedback = Feedback { (scheduler, _) -> Signal<Event, Never> in
            return pipe.output.observe(on: scheduler)
        }
        return (feedback, pipe.input.send)
    }

    /// Create a feedback which starts the given effect when the system has been
    /// initialized.
    public init<Effect: SignalProducerConvertible>(
        whenInitialized effect: Effect
    ) where Effect.Value == Event, Effect.Error == Never {
        self.init { scheduler, state in
            return state
                .flatMapOnce { _ in effect }
                .observe(on: scheduler)
        }
    }

    public init(from signal: Signal<Event, Never>) {
        self.init { (scheduler, _) -> Signal<Event, Never> in
            return signal.observe(on: scheduler)
        }
    }

    /// Create a feedback which samples the first occurence from the
    /// state transform results, until a `nil` is observed afterwards.
    public init<U, Effect: SignalProducerConvertible>(
        firstUntilNil transform: @escaping (State) -> U?,
        effect: @escaping (U) -> Effect
    ) where Effect.Value == Event, Effect.Error == Never {
        self.init { scheduler, state in
            return state
                .scan(into: (true, nil)) { (current: inout (isPreviouslyNil: Bool, value: U?), state: State) in
                    switch transform(state) {
                    case let .some(value) where current.isPreviouslyNil:
                        current = (isPreviouslyNil: false, value: value)
                    case .some:
                        current = (isPreviouslyNil: false, value: nil)
                    case .none:
                        current = (isPreviouslyNil: true, value: nil)
                    }
                }
                .filterMap { $0.value }
                .flatMapLatest(effect)
                .observe(on: scheduler)
        }
    }
}
