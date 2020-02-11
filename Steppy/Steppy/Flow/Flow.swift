import UIKit

/// Represents the root or containing view of a stack of view controllers.
public protocol Flow {
    /// Present the given view controller. The presentation style is decided by the flow.
    ///
    /// - parameters:
    ///   - viewController: The view controller to present.
    ///   - animated: Whether the presentation should be animated.
    ///   - completion: The callback to be called as the presentation completes.
    func present(_ viewController: UIViewController, animated: Bool, completion: (() -> Void)?)
    
    /// Replace the current view controller stack with the current view controller.
    /// This applies primarily to instances of NavigationFlow. In other types of Flow
    /// this is equivalent to present(_ viewController:animated:completion:)
    ///
    /// - parameters:
    ///   - viewController: The view controller which should replace all others in the stack
    ///   - animated: Whether the presentation should be animated.
    func replace(with viewController: UIViewController, animated: Bool)
    
    /// Dismiss the current flow.
    ///
    /// The flow gets to decide whether it is dismissed partially, e.g. only the top view
    /// controller in a navigational flow, or completely.
    func dismiss(animated: Bool, completion: (() -> Void)?)
}

extension UINavigationController {
    public enum DismissalStyle {
        case pop
        case popToRoot
        case dismiss(parent: Flow)
    }
    
    public var navigationFlow: Flow {
        return navigationFlow(dismissalStyle: .pop)
    }
    
    public func navigationFlow(dismissalStyle: DismissalStyle = .pop, alwaysHidesBottomBars: Bool = false) -> Flow {
        return NavigationFlow(
            navigationController: self,
            dismissalStyle: dismissalStyle,
            alwaysHidesBottomBars: alwaysHidesBottomBars
        )
    }
    
    public struct NavigationFlow: Flow {
        private weak var navigationController: UINavigationController?
        private let dismissalStyle: DismissalStyle
        private let alwaysHidesBottomBars: Bool
        
        fileprivate init(navigationController: UINavigationController, dismissalStyle: DismissalStyle, alwaysHidesBottomBars: Bool) {
            self.navigationController = navigationController
            self.dismissalStyle = dismissalStyle
            self.alwaysHidesBottomBars = alwaysHidesBottomBars
        }
        
        public func present(_ viewController: UIViewController, animated: Bool, completion: (() -> Void)?) {
            viewController.hidesBottomBarWhenPushed = viewController.hidesBottomBarWhenPushed || alwaysHidesBottomBars
            navigationController?.pushViewController(viewController, animated: animated)
            navigationTransitionCompletion(completion)
        }
        
        public func replace(with viewController: UIViewController, animated: Bool) {
            viewController.hidesBottomBarWhenPushed = viewController.hidesBottomBarWhenPushed || alwaysHidesBottomBars
            navigationController?.setViewControllers([viewController], animated: animated)
            navigationTransitionCompletion(nil)
        }
        
        public func dismiss(animated: Bool, completion: (() -> Void)?) {
            switch dismissalStyle {
            case .pop:
                self.navigationController?.popViewController(animated: animated)
                navigationTransitionCompletion(completion)
                
            case .popToRoot:
                self.navigationController?.popToRootViewController(animated: animated)
                navigationTransitionCompletion(completion)
                
            case let .dismiss(parent):
                parent.dismiss(animated: animated, completion: completion)
            }
        }
        
        private func navigationTransitionCompletion(_ completion: (() -> Void)?) {
            guard let transition = self.navigationController?.transitionCoordinator else {
                completion?()
                return
            }
            transition.animate(alongsideTransition: nil, completion: { _ in completion?() })
        }
    }
}
