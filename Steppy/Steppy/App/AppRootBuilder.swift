import UIKit
import ReactiveSwift
import ReactiveCocoa

struct AppRootBuilder {
    let keychain = SteppyKeychain()
    let businessController = SteppyBusinessController(network: Network())
    let navigationController = UINavigationController()
    let window: UIWindow

    init() {
        navigationController.navigationBar.isTranslucent = false
        window = UIWindow.init(frame: UIScreen.main.bounds)
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
    }

    func makeAppRoot() -> UIWindow {
        let appFlowController = AppRootFlowController(
            navigation: navigationController.navigationFlow,
            builders: self
        )

        let appViewModel = AppRootViewModel(keychain: keychain)
        
        appViewModel.routes
            .observe(on: UIScheduler())
            .observeValues(appFlowController.handle)

        let appRootViewController = AppRootViewController(appViewModel: appViewModel)
        navigationController.viewControllers = [appRootViewController]

        return window
    }

    func makeHome() -> UIViewController {
        //let homeViewModel = HomeViewModel.init(businessController: businessController, apiToken: "")
        return HomeViewController(title: "Steppy", keychain: keychain)
    }

    func makeOnboarding() -> UIViewController {
        return OnboardingViewController(title: "Sign Up", keychain: keychain)
    }
}
