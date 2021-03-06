import ReactiveSwift
import ReactiveFeedback
import Bento

final class OnboardingViewModel: ViewModelProtocol {
    let state: Property<State>
    private let box = Box<SectionId, RowId>.empty
    private let input = Feedback<State, Event>.input()
    private let keychain: KeychainProtocol
    init(
        scheduler: DateScheduler = QueueScheduler.main,
        businessController: BusinessControllerProtocol,
        keychain: KeychainProtocol
    ) {
        self.keychain = keychain
        
        state = Property<OnboardingViewModel.State>(
            initial: .idle(.init(email: "", password: "")),
            scheduler: scheduler,
            reduce: OnboardingViewModel.reduce,
            feedbacks: [
                input.feedback,
                OnboardingViewModel.whenSigningIn(
                    businessController: businessController,
                    keychain: keychain
                )
            ]
        )
    }
    
    //MARK - Renderer
    public func render(state: State) -> Box<SectionId, RowId> {
        
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
        case .succeeded:
            return Box.empty
            //|-+ renderSuccess()
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
    
    private func renderIdle(context: Context?) -> Section<SectionId, RowId> {
        let space =  Component.EmptySpace(height: 20)
        
        func didChangeUsername(_ username: String?) {
            send(action: .didChangeUsername(username ?? ""))
        }
        
        func didChangePassword(_ password: String?) {
            send(action: .didChangePassword(password ?? ""))
        }
        
        let username = Node(
            id: RowId.username,
            component: Component.TextInput(
                title: "e-mail: ",
                placeholder: "e-mail or username here",
                text: TextValue(stringLiteral: context?.email ?? ""),
                keyboardType: .emailAddress,
                isEnabled: true,
                textWillChange: nil,
                textDidChange: didChangeUsername,
                styleSheet: Component.TextInput.StyleSheet()
            )
        )
        
        let password = Node(
            id: RowId.password,
            component: Component.TextInput(
                title: "password: ",
                placeholder: "password here",
                keyboardType: .alphabet,
                isEnabled: true,
                textWillChange: nil,
                textDidChange: didChangePassword,
                styleSheet: Component.TextInput.StyleSheet()
            )
        )
        
        func didTapSend() {
            send(action: .userDidTapSend)
        }
        
        let sendButton = Node(
            id: RowId.sendButton,
            component: Component.Button(
                title: "Sign Up",
                isEnabled: true,
                didTap: didTapSend,
                styleSheet: Component.Button.StyleSheet(button: ButtonStyleSheet())
            )
        )
        
        return Section(
            id: .form,
            header: space,
            footer: space,
            items: [username, password, sendButton]
        )
    }
    
    enum SectionId: Hashable {
        case form
        case loading
    }
    
    enum RowId: Hashable {
        case space
        case username
        case password
        case sendButton
        case loading
    }
    
    enum State {
        case idle(Context)
        case loading(Context)
        case succeeded
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
        var email: String = ""
        var password: String = ""
    }
    
    enum Event {
        case ui(Action)
        case didFail
        case didSucceed
    }
    
    enum Action {
        case didChangeUsername(String)
        case didChangePassword(String)
        case userDidTapSend
    }
    
    enum Route {
        case authenticated
    }
}

//MARK - Feedback system
extension OnboardingViewModel {
    func send(action: OnboardingViewModel.Action) {
        input.observer(.ui(action))
    }

    private static func reduce(_ state: State, _ event: Event) -> State {
        switch event {
        case let .ui(.didChangePassword(password)):
            return .idle(state.context.with(set(\.password, password)))
        case let .ui(.didChangeUsername(username)):
            return .idle(state.context.with(set(\.email, username)))
        case .ui(.userDidTapSend):
            return .loading(state.context)
        case .didFail, .didSucceed:
            return .idle(.init())
        }
    }
}

extension OnboardingViewModel {
    private static func whenSigningIn(
        businessController: BusinessControllerProtocol,
        keychain: KeychainProtocol
    ) -> Feedback<State, Event> {
        return Feedback { state -> SignalProducer<Event, Never> in
            guard case .loading = state else { return .empty }

            return businessController
                .createNewSession(
                    email: state.context.email,
                    password: state.context.password
                )
                .ignoreError()
                .injectSideEffect(keychain.setSession)
                .map(value: Event.didSucceed)
        }
    }
}
