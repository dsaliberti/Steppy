struct AppRootFlowController {
    private let navigation: Flow
    private let builders: AppRootBuilder
    
    init(navigation: Flow, builders: AppRootBuilder) {
        self.navigation = navigation
        self.builders = builders
    }
    
    func handle(_ route: AppRootViewModel.Route) {
        switch route {
        case .home:
            return navigation.replace(with: builders.makeHome(), animated: false)
        case .signUp:
            return navigation.replace(with: builders.makeOnboarding(), animated: false)
        }
    }
}
