import KeychainAccess

struct SteppyKeychain {
    let keychain = Keychain(service: "com.dsaliberti.steppy")
    let apiTokenKey = "apiToken"

    func getToken() -> String? {
        return keychain[string: apiTokenKey]
    }

    func setToken(_ token: String) {
        try? keychain.set(token, key: apiTokenKey)
    }

    func clearToken() {
        try? keychain.remove(apiTokenKey)
    }
}
