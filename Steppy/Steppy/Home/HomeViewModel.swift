struct HomeViewModel {
    
    init(
        businessController: BusinessControllerProtocol,
        apiToken: String
    ) {
        
    }

    enum State {
        case fetchingUser
        case succeeded
        case failed
    }

    enum Route {
        case logout
    }
    
    enum Event {
        case userDidLoadEmpty
        case userDidLoad
        case userDidFail
        case healthReadStepsPermissionGranted
        case healthWriteStepsPermissionGranted
        case healthReadWritePermissionGranted
    }
}
