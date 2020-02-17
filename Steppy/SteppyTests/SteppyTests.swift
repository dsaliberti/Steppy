@testable import Steppy
import ReactiveSwift
import Nimble
import XCTest

class HomeViewModelTests: BaseViewModelTestCase {
    override func setUp() { }

    override func tearDown() {
        SteppyKeychain().clearSession()
    }

    func test_when_idle() {
        perform(stub: { testScheduler -> HomeViewModel in
            return HomeViewModelTests.makeHomeViewModel(testScheduler)
        }, when: { viewModel, testScheduler in
            return
        }) { states in

            let expected: [HomeViewModel.State] = [.idle(HomeViewModel.Context())]
            expect(states).to(equal(expected))
        }
    }

    func test_when_healthkit_is_authorized() {
        perform(stub: { testScheduler -> HomeViewModel in
            return HomeViewModelTests.makeHomeViewModel(testScheduler)
        }, when: { viewModel, testScheduler in
            viewModel.send(action: .userDidTapSyncHealthKit)
            testScheduler.advance()
        }) { states in
            
            let context = HomeViewModel.Context()
            let authorized = HKStepsAuthorizationStatus.sharingAuthorized
            
            let expected: [HomeViewModel.State] = [
                .idle(context),
                .userAuthorizingHealthKitAccess(context),
                .idle(context.with(set(\.healthKitAuthorizationStatus, authorized)))
            ]

            expect(states).to(equal(expected))
        }
    }

    func test_when_user_logout() {
        perform(stub: { testScheduler -> HomeViewModel in
            return HomeViewModelTests.makeHomeViewModel(testScheduler)
        }, when: { viewModel, testScheduler in
            viewModel.send(action: .userDidTapLogout)
            testScheduler.advance()
        }) { states in
            
            let context = HomeViewModel.Context()

            let expected: [HomeViewModel.State] = [
                .idle(context),
                .logOut,
                .idle(context)
            ]

            expect(states).to(equal(expected))
        }
    }
}

extension HomeViewModelTests {
    static func makeHomeViewModel(_ scheduler: TestScheduler) -> HomeViewModel {
        return HomeViewModel(
            scheduler: scheduler,
            businessController: StubBusinessController(),
            apiToken: "api-token-here",
            userId: "user-id-here",
            keychain: StubKeychain(),
            healthKit: StubHealthKit()
        )
    }
}

open class BaseViewModelTestCase: XCTestCase {
    public func perform<ViewModel: ViewModelProtocol>(
        stub: (TestScheduler) -> ViewModel,
        when: (ViewModel, TestScheduler) -> Void,
        assert: ([ViewModel.State]) -> Void
    ) {
        let scheduler = TestScheduler()
        let viewModel = stub(scheduler)
        var states = [ViewModel.State]()
        viewModel.state.producer.startWithValues {
            states.append($0)
        }
        when(viewModel, scheduler)
        assert(states)
    }
}

struct StubKeychain: KeychainProtocol {
    func clearSession() {}
    
    func setSession(_ session: Session) {}
    
    var didChangeCompletion: (AuthenticationState) -> Void = {_ in }
    
    func getUserId() -> String? { return nil }
    
    func getToken() -> String? { return nil }
    
    func checkState() {}
}

struct StubHealthKit: HealthKit {
    func checkAuthorizationStatus() -> HKStepsAuthorizationStatus {
        return .sharingAuthorized
    }
    
    func requestAuthorization() -> SignalProducer<HKStepsAuthorizationStatus, Error> {
        return .value(.sharingAuthorized)
    }
    
    func readSteps(for date: Date) -> SignalProducer<Double, Error> {
        return .value(33)
    }
    
    func writeAndRead(steps: Int, date: Date) -> SignalProducer<Double, Error> {
        return .value(99)
    }
}

final class StubBusinessController: BusinessControllerProtocol {
    func post(steps: Int, apiToken: String, userId: String) -> SignalProducer<User, Error> {
        return .value(User(email: "email@here.com", stepCount: 33))
    }
    
    func createNewSession(email: String, password: String) -> SignalProducer<Session, Error> {
        return .value(Session(apiToken: "api-token-here", userId: "user-id-here"))
    }
    
    func user(with id: String, apiToken: String) -> SignalProducer<User, Error> {
        return .value(User(email: "email@here.com", stepCount: 33))
    }
}


extension HomeViewModel.State: Equatable {
    public static func == (lhs: HomeViewModel.State, rhs: HomeViewModel.State) -> Bool {
        switch (lhs, rhs) {
        case let (.idle(lContext), idle(rContext)),
             let (.userAuthorizingHealthKitAccess(lContext), .userAuthorizingHealthKitAccess(rContext)),
             let (.checkingHealthKitAuthorization(lContext), .checkingHealthKitAuthorization(rContext)),
             let (.fetchingStepsData(lContext), .fetchingStepsData(rContext)):
            return lContext == rContext

        case (.failed, .failed), (.logOut, .logOut):
            return true
        default:
            return false
        }
    }
}

extension HomeViewModel.Context: Equatable {
    public static func == (lhs: HomeViewModel.Context, rhs: HomeViewModel.Context) -> Bool {
        return lhs.healthKitAuthorizationStatus == rhs.healthKitAuthorizationStatus
            && lhs.steps == rhs.steps
    }
}
