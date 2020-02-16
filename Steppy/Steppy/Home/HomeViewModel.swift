import ReactiveSwift
import ReactiveFeedback
import Bento

struct HomeViewModel {
    let state: Property<State>
    //let routes: Signal<Route, Never>
    private let box = Box<SectionId, RowId>.empty
    private let input = Feedback<State, Event>.input()
    private let keychain: SteppyKeychain
    private let healthKit: HealthKit
    let space =  Component.EmptySpace(height: 20, styleSheet: ViewStyleSheet<UIView>(backgroundColor: .lightGray))
    init(
        scheduler: DateScheduler = QueueScheduler.main,
        businessController: BusinessControllerProtocol,
        apiToken: String,
        keychain: SteppyKeychain,
        healthKit: HealthKit
    ) {
        self.keychain = keychain
        self.healthKit = healthKit
        state = Property<HomeViewModel.State>(
            initial: .idle(.init()),
            scheduler: scheduler,
            reduce: HomeViewModel.reduce,
            feedbacks: [
                input.feedback,
                HomeViewModel.whenCheckingHealthKitAuthorization(healthKit: healthKit),
                HomeViewModel.whenFetchingStepsData(
                    businessController: businessController,
                    apiToken: apiToken,
                    healthKit: healthKit
                ),
                HomeViewModel.whenLogingOut(
                    businessController: businessController,
                    keychain: keychain
                ),
                HomeViewModel.whenUserAuthorizingHealthKitAccess(healthKit: healthKit)
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

//MARK - ViewLifeCycle
    func viewDidLoad() {
        input.observer(.viewDidLoad)
    }

    func appBecomeActive() {
        input.observer(.appBecomeActive)
    }
    
//MARK - Renderer
    public func render(state: State) -> Box<SectionId, RowId> {
        print("render state", state)
        
        switch state {
        case .idle, .checkingHealthKitAuthorization:
            return Box.empty
                |-+ renderIdle(context: state.context)
                |-+ renderHealthKit(context: state.context)
                |-+ renderLogout()

        case .fetchingStepsData, .logOut:
            return Box.empty
                |-+ renderLoading()
        case .failed:
            return Box.empty
            //|-+ renderFailure()
        case .userAuthorizingHealthKitAccess:
            return Box.empty
                |-+ renderIdle(context: state.context)
        }
    }

    private func renderLoading() -> Section<SectionId, RowId> {
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
    
    private func renderHealthKit(context: Context) -> Section<SectionId, RowId> {
        func didTapSyncHealthKitButton() {
            send(action: .userDidTapSyncHealthKit)
        }

        let healthKitButton = Node(
            id: RowId.requestHealthKitButton,
            component: Component.Button(
                title: "Sync with Apple Health®",
                didTap: didTapSyncHealthKitButton,
                styleSheet: Component.Button.StyleSheet(button: ButtonStyleSheet())
            )
        )

        func description(_ text: String) -> Node<RowId> {
            return Node(
                id: .healthKitDescription,
                component: Component.Description(
                    text: text,
                    didTap: {
                        print("tap")
                    }, styleSheet: Component.Description.StyleSheet(
                        text: LabelStyleSheet(
                            font: UIFont.preferredFont(
                                forTextStyle: .footnote
                            ),
                            textColor: .darkGray,
                            numberOfLines: 0
                        )
                    )
                )
            )
        }
        
        func node(from status: HKStepsAuthorizationStatus) -> Node<RowId> {
            switch status {
            case .unavailable:
                return description("HealthKit® is unavailable for this device.")
            case .notDetermined, .unknown:
                return healthKitButton
            case .cancelled, .denied:
                return description("Steppy has no permission to write HealthKit® data. \nYou can go to Apple Health® app / Sources to enable Steppy's access to write step count.")
            case .sharingAuthorized:
                return description("Authorised to write your step count to HealthKit® ✓")
            }
        }

        return Section(
            id: SectionId.healthKit,
            footer: space,
            items: [node(from: context.healthKitAuthorizationStatus)]
        )
    }

    private func renderLogout() -> Section<SectionId, RowId> {
        func didTapLogout() {
            send(action: .userDidTapLogout)
        }
        
        let logoutButton = Node(
            id: RowId.logoutButton,
            component: Component.Button(
                title: "Logout",
                didTap: didTapLogout,
                styleSheet: Component.Button.StyleSheet(button: ButtonStyleSheet())
            )
        )

        return Section(
            id: .logout,
            footer: space,
            items: [logoutButton]
        )
    }
        
    private func renderIdle(context: Context) -> Section<SectionId, RowId> {

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

        let generateStepsButton = Node(
            id: RowId.generateStepsButton,
            component: Component.Button(
                title: "Generate steps randomly",
                isEnabled: true,
                didTap: { },
                styleSheet: Component.Button.StyleSheet(button: ButtonStyleSheet())
            )
        )

        return Section(
            id: .stepsView,
            header: space,
            footer: space,
            items: [stepsLabel, generateStepsButton]
        )
    }

    enum SectionId: Hashable {
        case stepsView
        case generateSteps
        case healthKit
        case logout
        case loading
    }

    enum RowId: Hashable {
        case space
        case stepsLabel
        case requestHealthKitButton
        case healthKitDescription
        case generateStepsButton
        case logoutButton
        case loading
    }

    enum State {
        case idle(Context)
        case fetchingStepsData(Context)
        case userAuthorizingHealthKitAccess(Context)
        case checkingHealthKitAuthorization(Context)
        case logOut
        case failed

        var context: Context {
            switch self {
            case let .idle(context),
                 let .fetchingStepsData(context),
                 let .userAuthorizingHealthKitAccess(context):
                return context
            default:
                return Context()
            }
        }
    }

    struct Context: With {
        var healthKitAuthorizationStatus: HKStepsAuthorizationStatus = .unknown
        var userId: String = "1" //this should be injected from /session response
        var steps: String = "0"
        //apiDataUpToDate
        //hkDataUpToDate
        var stepsToSync: Int = 0
    }

    enum Event {
        case ui(Action)
        case viewDidLoad
        case appBecomeActive
        case userDidLoad(Double)
        case userDidLogout
        case healthKitPermissionsFinished(status: HKStepsAuthorizationStatus)
        case healthKitCheckAuthorizationStatusFinished(status: HKStepsAuthorizationStatus)
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
    private static func reduce(_ state: State, _ event: Event) -> State {
        switch event {
        case .ui(.userDidTapSyncHealthKit):
            return .userAuthorizingHealthKitAccess(state.context)
            
        case .appBecomeActive, .viewDidLoad:
            return .checkingHealthKitAuthorization(state.context)
            
        case let .healthKitCheckAuthorizationStatusFinished(status: status):
            return .fetchingStepsData(
                state.context.with(set(\.healthKitAuthorizationStatus, status))
            )

        case let .healthKitPermissionsFinished(status: status):
            return .idle(state.context.with(set(\.healthKitAuthorizationStatus, status)))

        case let .userDidLoad(stepCount):
            return .idle(
                state.context.with(set(\.steps, "\(stepCount)"))
            )
        case .ui(.userDidTapGenerateStepsRandomly):
            return state

        case .ui(.userDidTapLogout):
            return .logOut

        case .userDidLogout:
            return state
        }
    }

    func send(action: HomeViewModel.Action) {
        input.observer(.ui(action))
    }
}

extension HomeViewModel {
    
    private static func whenCheckingHealthKitAuthorization(
        healthKit: HealthKit
    ) -> Feedback<State, Event> {
        return Feedback { state -> SignalProducer<Event, Never> in
            guard case .checkingHealthKitAuthorization = state else { return .empty }

            return .value(.healthKitCheckAuthorizationStatusFinished(
                status: healthKit.checkAuthorizationStatus()
                )
            )
        }
    }

    private static func whenUserAuthorizingHealthKitAccess(
        healthKit: HealthKit
    ) -> Feedback<State, Event> {
        return Feedback { state -> SignalProducer<Event, Never> in
            guard case .userAuthorizingHealthKitAccess = state else { return .empty }
            return healthKit.requestAuthorization()
                .ignoreError()
                .map { .healthKitPermissionsFinished(status: $0) }
        }
    }
    
    private static func whenFetchingStepsData(
        businessController: BusinessControllerProtocol,
        apiToken: String,
        healthKit: HealthKit
    ) -> Feedback<State, Event> {
        return Feedback { state -> SignalProducer<Event, Never> in
            guard case let .fetchingStepsData(context) = state else { return .empty }

            let healthKitSteps = healthKit.readSteps(for: Date())
            
            let userSteps = businessController.user(
                with: context.userId,
                apiToken: apiToken
            ).map(\.stepCount)

            return SignalProducer.zip([healthKitSteps, userSteps])
                .ignoreError()
                .map {
                    return Event.userDidLoad($0.max() ?? 0)
                }
        }
    }
    
    private static func whenLogingOut(
        businessController: BusinessControllerProtocol,
        keychain: SteppyKeychain
    ) -> Feedback<State, Event> {
        return Feedback { state -> SignalProducer<Event, Never> in
            guard case .logOut = state else { return .empty }

            DispatchQueue.main.async {
                keychain.clearToken()
            }

            return SignalProducer(value: .userDidLogout)
        }
    }
}

