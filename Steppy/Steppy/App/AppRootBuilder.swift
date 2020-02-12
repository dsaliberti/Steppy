import UIKit
import ReactiveSwift
import ReactiveCocoa

struct AppRootBuilder {
    let keychain: SteppyKeychain
    let businessController = SteppyBusinessController(network: Network())
    let window: UIWindow
    let navigationController = SteppyNavigationController()

    init() {
        window = UIWindow.init(frame: UIScreen.main.bounds)
        window.makeKeyAndVisible()
        window.rootViewController = navigationController

        keychain = SteppyKeychain()
        keychain.didChangeCompletion = makeAppRoot(state:)
        keychain.checkState()
    }

    func makeAppRoot(state: SteppyKeychain.AuthenticationState) {
        switch state {
        case .unauthenticated:
            navigationController.navigationFlow.replace(with: makeOnboarding(), animated: false)
        case let .authenticated(apiToken: token):
            navigationController.navigationFlow.replace(with: makeHome(apiToken: token), animated: false)
        }
    }

    func makeHome(apiToken: String) -> UIViewController {
        let homeViewModel = HomeViewModel(businessController: businessController, apiToken: apiToken)
        return HomeViewController(
            title: "Steppy",
            keychain: keychain,
            homeViewModel: homeViewModel
        )
    }

    func makeOnboarding() -> UIViewController {
        return OnboardingViewController(title: "Sign Up", keychain: keychain)
    }
}

class SteppyNavigationController: UINavigationController {
    init() {
        super.init(nibName: nil, bundle: nil)
        navigationBar.isTranslucent = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
