import ReactiveSwift
import ReactiveFeedback

struct OnboardingViewModel {

    private let state: Property<State>
    let routes: Signal<Route, Never>
    
    init(
        scheduler: DateScheduler = QueueScheduler.main,
        businessController: BusinessControllerProtocol,
        keychain: SteppyKeychain
    ) {
        state = Property<State>(
            initial: .idle,
            scheduler: scheduler,
            reduce: OnboardingViewModel.reduce,
            feedbacks: [
                OnboardingViewModel.whenSigningIn(
                    businessController: businessController,
                    keychain: keychain
                )
            ]
        )

        _  = state.signal.logEvents()

        routes = state.signal.compactMap { state -> Route? in
            switch state {
            default: return nil
            }
        }

        _ = routes.logEvents()
    }

    enum State {
        case idle
        case loading
        case succeeded
        case failed
    }
    
    enum Event {
        case didSend
        case didFail
        case didSucceed
    }
    
    enum Route {
        case dismiss
    }
}

extension OnboardingViewModel {
    private static func reduce(_ state: State, _ event: Event) -> State {
        switch event {
        case .didSend, .didFail, .didSucceed: return state
        }
    }
}

extension OnboardingViewModel {
    private static func whenSigningIn(
        businessController: BusinessControllerProtocol,
        keychain: SteppyKeychain
        ) -> Feedback<State, Event> {
        return Feedback { state -> SignalProducer<Event, Never> in
            guard case .idle = state else { return .empty }
            return SignalProducer(value: Event.didSend)
        }
    }
}
