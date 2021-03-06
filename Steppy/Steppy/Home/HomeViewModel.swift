import ReactiveSwift
import ReactiveFeedback
import Bento

final class HomeViewModel: ViewModelProtocol {
    let state: Property<State>
    private let box = Box<SectionId, RowId>.empty
    private let input = Feedback<State, Event>.input()
    private let keychain: KeychainProtocol
    private let healthKit: HealthKit
    let space =  Component.EmptySpace(height: 20, styleSheet: ViewStyleSheet<UIView>(backgroundColor: .white))
    init(
        scheduler: DateScheduler = QueueScheduler.main,
        businessController: BusinessControllerProtocol,
        apiToken: String,
        userId: String,
        keychain: KeychainProtocol,
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
                    userId: userId,
                    healthKit: healthKit
                ),
                HomeViewModel.whenLogingOut(
                    businessController: businessController,
                    keychain: keychain
                ),
                HomeViewModel.whenUserAuthorizingHealthKitAccess(healthKit: healthKit),
                HomeViewModel.whenPostingSteps(
                    businessController: businessController,
                    apiToken: apiToken,
                    userId: userId,
                    healthKit: healthKit
                )
            ]
        )
    }


    //MARK - ViewLifeCycle
    func viewDidLoad() {
        input.observer(.viewDidLoad)
    }

    //MARK - AppLifeCycle
    func appBecomeActive() {
        input.observer(.appBecomeActive)
    }
    
    //MARK - Renderer
    public func render(state: State) -> Box<SectionId, RowId> {
        switch state {
        case .idle, .checkingHealthKitAuthorization, .postingSteps:
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
                    didTap: { },
                    styleSheet: Component.Description.StyleSheet(
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
                didTap: {
                    self.send(action: .userDidTapGenerateStepsRandomly)
                },
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
        case postingSteps(Context)
        case checkingHealthKitAuthorization(Context)
        case logOut
        case failed

        var context: Context {
            switch self {
            case let .idle(context),
                 let .fetchingStepsData(context),
                 let .userAuthorizingHealthKitAccess(context),
                 let .postingSteps(context),
                 let .checkingHealthKitAuthorization(context):
                return context
            case .logOut, .failed:
                return Context()
            }
        }
    }

    struct Context: With {
        var healthKitAuthorizationStatus: HKStepsAuthorizationStatus = .unknown
        var steps: String = "0"
        var stepsToPost: Int = 0
        
    }

    enum Event {
        case ui(Action)
        case viewDidLoad
        case appBecomeActive
        case userDidLoad(Int)
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

        case .ui(.userDidTapGenerateStepsRandomly):
            return .postingSteps(state.context)

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

        case .ui(.userDidTapLogout):
            return .logOut

        case .userDidLogout:
            return .idle(.init())
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
        userId: String,
        healthKit: HealthKit
    ) -> Feedback<State, Event> {
        return Feedback { state -> SignalProducer<Event, Never> in
            guard case .fetchingStepsData = state else { return .empty }

            let healthKitSteps = healthKit.readSteps(for: Date())
            
            let userSteps = businessController.user(
                with: userId,
                apiToken: apiToken
            ).map(\.stepCount)

            return SignalProducer.zip([healthKitSteps, userSteps])
                .ignoreError()
                .map {
                    return Event.userDidLoad(Int($0.max() ?? 0))
                }
        }
    }

    private static func whenPostingSteps(
        businessController: BusinessControllerProtocol,
        apiToken: String,
        userId: String,
        healthKit: HealthKit
    ) -> Feedback<State, Event> {
        return Feedback { state -> SignalProducer<Event, Never> in
            guard case .postingSteps = state else { return .empty }
            let randomSteps = Int.random(in: 0 ..< 10)
            let healthKitSteps = healthKit.writeAndRead(steps: randomSteps, date: Date())

            let userSteps = businessController.post(steps: randomSteps, apiToken: apiToken, userId: userId)
                .map(\.stepCount)

            return SignalProducer.zip([healthKitSteps, userSteps])
                .ignoreError()
                .map {
                    return Event.userDidLoad(Int($0.max() ?? 0))
                }
        }
    }
    
    private static func whenLogingOut(
        businessController: BusinessControllerProtocol,
        keychain: KeychainProtocol
    ) -> Feedback<State, Event> {
        return Feedback { state -> SignalProducer<Event, Never> in
            guard case .logOut = state else { return .empty }
            keychain.clearSession()
            return SignalProducer(value: .userDidLogout)
        }
    }
}

