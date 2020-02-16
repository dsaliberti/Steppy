import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = AppRootBuilder().window
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        guard let rootViewController = window?.rootViewController as? SteppyNavigationController,
            let activeHomeViewController = rootViewController.viewControllers.first as? HomeViewController else { return }

        activeHomeViewController.appBecomeActive()
    }

    func applicationWillTerminate(_ application: UIApplication) { }
}
