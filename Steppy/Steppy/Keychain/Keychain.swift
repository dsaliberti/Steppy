import KeychainAccess

protocol KeychainProtocol {
    func clearSession()
    func setSession(_ session: Session)
    var didChangeCompletion: (AuthenticationState) -> Void { get set }
    func getUserId() -> String?
    func getToken() -> String?
    func checkState()
}

enum AuthenticationState {
    case authenticated(apiToken: String, userId: String)
    case unauthenticated
}

class SteppyKeychain: KeychainProtocol {
    private let keychain = Keychain(service: "com.dsaliberti.steppy")
    private let apiTokenKey = "apiToken"
    private let userIdKey = "userId"

    var didChangeCompletion: (AuthenticationState) -> Void = {_ in }

    func getUserId() -> String? {
        return keychain[string: userIdKey]
    }

    func getToken() -> String? {
        return keychain[string: apiTokenKey]
    }

    func setSession(_ session: Session) {
        try? keychain.set(session.apiToken, key: apiTokenKey)
        try? keychain.set(session.userId, key: userIdKey)
        
        DispatchQueue.main.sync {
            didChangeCompletion(
                .authenticated(
                    apiToken: session.apiToken,
                    userId: session.userId
                )
            )
        }
    }

    func clearSession() {
        try? keychain.remove(apiTokenKey)
        try? keychain.remove(userIdKey)
        didChangeCompletion(.unauthenticated)
    }

    func checkState() {
        guard let token = getToken(),
            let userId = getUserId() else {
            return didChangeCompletion(.unauthenticated)
        }

        didChangeCompletion(.authenticated(apiToken: token, userId: userId))
    }
}
