import Foundation

protocol BusinessControllerProtocol {
    var network: Connectable { get }
    func createNewSession(
        email: String,
        password: String,
        completion: @escaping (Data?, URLResponse?, Error?) -> Void
    )
}

public final class SteppyBusinessController: BusinessControllerProtocol {
    let baseURLString = "https://www.google.com"
    let network: Connectable

    public init(network: Connectable) {
        self.network = network
    }

    public func createNewSession(
        email: String,
        password: String,
        completion: @escaping (Data?, URLResponse?, Error?) -> Void
    ) {
        let url = URL(string: "\(baseURLString)/sessions/new")!

        let body = ["email": email, "password": password]
        let method = "post"
        
        let request = SteppyBusinessController.makeURLRequest(
            url: url,
            body: body,
            method: method,
            timeout: network.timeoutForRequest
        )
        
        network.request(request, completion: completion)
    }

    public func user(
        with id: String,
        apiToken: String,
        completion: @escaping (Data?, URLResponse?, Error?) -> Void
    ) {
        let url = URL(string: "\(baseURLString)/users/\(id)")!
        let method = "get"
        
        let request = SteppyBusinessController.makeURLRequest(
            url: url,
            token: apiToken,
            body: [:],
            method: method,
            timeout: network.timeoutForRequest
        )
        
        network.request(request, completion: completion)
    }
}

extension SteppyBusinessController {
    static func makeURLRequest(
        url: URL,
        token: String? = nil,
        body: [String: String],
        method: String,
        timeout: TimeInterval
    ) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: timeout)
        request.httpMethod = method.uppercased()
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        if let token = token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }
}
