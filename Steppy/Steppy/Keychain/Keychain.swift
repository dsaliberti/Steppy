import KeychainAccess

class SteppyKeychain {
    let keychain = Keychain(service: "com.dsaliberti.steppy")
    let apiTokenKey = "apiToken"

    enum AuthenticationState {
        case authenticated(apiToken: String)
        case unauthenticated
    }
    
    var didChangeCompletion: (AuthenticationState) -> Void = {_ in }

    func getToken() -> String? {
        return keychain[string: apiTokenKey]
    }

    func setToken(_ token: String) {
        try? keychain.set(token, key: apiTokenKey)
        didChangeCompletion(.authenticated(apiToken: token))
    }

    func clearToken() {
        try? keychain.remove(apiTokenKey)
        didChangeCompletion(.unauthenticated)
    }

    func checkState() {
        guard let token = getToken() else {
            return didChangeCompletion(.unauthenticated)
        }

        didChangeCompletion(.authenticated(apiToken: token))
    }
}
