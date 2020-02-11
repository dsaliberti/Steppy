import ReactiveSwift
import ReactiveFeedback

struct AppRootViewModel {
    private let state: Property<State>
    let routes: Signal<Route, Never>
    
    init(
        scheduler: DateScheduler = QueueScheduler.main,
        keychain: SteppyKeychain
    ) {
        state = Property<State>(
            initial: .unknown,
            scheduler: scheduler,
            reduce: AppRootViewModel.reduce,
            feedbacks: [
                AppRootViewModel.whenUnknown(keychain: keychain)
            ]
        )

        routes = state.signal.compactMap { state -> Route? in
            switch state {
            case .authenticated:
                return Route.home
            case .unauthenticated:
                return Route.signUp
            case .unknown:
                return nil
            }
        }
    }
}

extension AppRootViewModel {
    private static func reduce(_ state: State, _ event: Event) -> State {
        switch event {
        case .appDidLaunch:
            return .unknown
        case .authenticationNotFound:
            return .unauthenticated
        case .authenticationFound:
            return .authenticated
        }
    }
}

extension AppRootViewModel {
    private static func whenUnknown(
        keychain: SteppyKeychain
    ) -> Feedback<State, Event> {
        return Feedback { state -> SignalProducer<Event, Never> in
            guard case .unknown = state else { return .empty }
            guard let token = keychain.getToken() else {
                return SignalProducer(value: .authenticationNotFound)
            }

            return SignalProducer(value: .authenticationFound(token))
        }
    }
}

extension AppRootViewModel {
    private enum State {
        case unknown
        case authenticated
        case unauthenticated
    }

    enum Event {
        case appDidLaunch
        case authenticationFound(String)
        case authenticationNotFound
    }

    enum Route {
        case home
        case signUp
    }
}
