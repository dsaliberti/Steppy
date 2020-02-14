import ReactiveSwift
import ReactiveFeedback
import Bento

struct HomeViewModel {
    let state: Property<State>
    //let routes: Signal<Route, Never>
    private let box = Box<SectionId, RowId>.empty
    private let input = Feedback<State, Event>.input()
    private let keychain: SteppyKeychain
    init(
        scheduler: DateScheduler = QueueScheduler.main,
        businessController: BusinessControllerProtocol,
        apiToken: String,
        keychain: SteppyKeychain
    ) {
        self.keychain = keychain
        
        state = Property<HomeViewModel.State>(
            initial: .idle(.init()),
            scheduler: scheduler,
            reduce: HomeViewModel.reduce,
            feedbacks: [
                input.feedback,
                HomeViewModel.whenLogout(
                    businessController: businessController,
                    keychain: keychain
                )
            ]
        )
    }

//        routes = state.signal.compactMap { state -> Route? in
//            switch state {
//            case .succeeded:
//                return .authenticated
//            default: return nil
//            }
//        }

//MARK - Renderer
    public func render(state: State) -> Box<SectionId, RowId> {
        print("render state")
        
        switch state {
        case .idle:
            return Box.empty
                |-+ renderIdle(context: state.context)
        case .loading:
            return Box.empty
                |-+ renderLoading()
        case .failed:
            return Box.empty
            //|-+ renderFailure()
            
        }
    }

    private func renderLoading() -> Section<SectionId, RowId> {
        let space =  Component.EmptySpace(height: 20)
        let loading = Node(
            id: RowId.loading,
            component: Component.Activity(
                isLoading: true,
                styleSheet: Component.Activity.StyleSheet(
                    activityIndicator: ActivityIndicatorStyleSheet(
                        activityIndicatorViewStyle: .gray
                    )
                )
            )
        )

        return Section(
            id: SectionId.loading,
            header: space,
            footer: space,
            items: [loading]
        )
    }

    private func renderIdle(context: Context) -> Section<SectionId, RowId> {
        let space =  Component.EmptySpace(height: 20)

        let stepsLabel = Node(
            id: RowId.stepsLabel,
            component: Component.ImageOrLabel(
                imageOrLabel: ImageOrLabelView.Content.text("\(context.steps) \nsteps"),
                styleSheet: Component.ImageOrLabel.StyleSheet(
                    imageOrLabel: ImageOrLabelView.StyleSheet(
                        fixedSize: CGSize.init(width: 100, height: 50),
                        backgroundColor: .lightGray,
                        cornerRadius: 10.0,
                        label: LabelStyleSheet(
                            backgroundColor: .red,
                            font: UIFont.systemFont(ofSize: 20, weight: .bold),
                            textColor: .white,
                            textAlignment: .center,
                            numberOfLines: 2,
                            lineBreakMode: .byClipping
                        )
                    )
                )
            )
        )

        let healthButton = Node(
            id: RowId.requestHealthKitButton,
            component: Component.Button(
                title: "Sync with Apple Health®",
                isEnabled: true,
                didTap: { },
                styleSheet: Component.Button.StyleSheet(button: ButtonStyleSheet())
            )
        )

        let generateStepsButton = Node(
            id: RowId.generateStepsButton,
            component: Component.Button(
                title: "Generate steps randomly",
                isEnabled: true,
                didTap: { },
                styleSheet: Component.Button.StyleSheet(button: ButtonStyleSheet())
            )
        )

        func didTapLogout() {
            send(action: .userDidTapLogout)
        }

        let logoutButton = Node(
            id: RowId.logoutButton,
            component: Component.Button(
                title: "Logout",
                isEnabled: true,
                didTap: didTapLogout,
                styleSheet: Component.Button.StyleSheet(button: ButtonStyleSheet())
            )
        )

        return Section(
            id: .form,
            header: space,
            footer: space,
            items: [stepsLabel, healthButton, generateStepsButton, logoutButton]
        )
    }

    enum SectionId: Hashable {
        case form
        case loading
    }

    enum RowId: Hashable {
        case space
        case stepsLabel
        case requestHealthKitButton
        case generateStepsButton
        case logoutButton
        case loading
    }

    enum State {
        case idle(Context)
        case loading(Context)
        case failed

        var context: Context {
            switch self {
            case let .idle(context):
                return context
            default:
                return Context()
            }
        }
    }

    struct Context: With {
        var healthKitReadEnabled: Bool = false
        var healthKitWriteEnabled: Bool = false
        var steps: String = ""
        var stepsToSync: Int = 0
    }

    enum Event {
        case ui(Action)
        case userDidLoad
        case userDidFail
        case userDidLogout
        case healthReadStepsPermissionGranted
        case healthWriteStepsPermissionGranted
        case healthReadWritePermissionGranted
    }

    enum Action {
        case userDidTapGenerateStepsRandomly
        case userDidTapSyncHealthKit
        case userDidTapLogout
    }

    enum Route {
        case authenticated
    }
}

//MARK - Feedback system
extension HomeViewModel {
    func send(action: HomeViewModel.Action) {
        input.observer(.ui(action))
    }

    private static func reduce(_ state: State, _ event: Event) -> State {
        switch event {
        case .ui(.userDidTapLogout):
            return .loading(state.context)
        default:
            return .idle(.init())
        }
    }
}

extension HomeViewModel {
    private static func whenLogout(
        businessController: BusinessControllerProtocol,
        keychain: SteppyKeychain
    ) -> Feedback<State, Event> {
        return Feedback { state -> SignalProducer<Event, Never> in
            guard case .loading = state else { return .empty }

            DispatchQueue.main.async {
                keychain.clearToken()
            }

            return SignalProducer(value: .userDidLogout)
        }
    }
}

