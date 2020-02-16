import Foundation
import ReactiveSwift

protocol BusinessControllerProtocol {
    var network: Connectable { get }
    func createNewSession(
        email: String,
        password: String,
        completion: @escaping (Data?, URLResponse?, Error?) -> Void
    )

    func user(
        with id: String,
        apiToken: String,
        completion: @escaping (Data?, URLResponse?, Error?) -> Void
    )

    func user(with id: String, apiToken: String) -> SignalProducer<User, Error>
}

public final class SteppyBusinessController: BusinessControllerProtocol {
    let baseURLString = "https://private-c594e6-steppy1.apiary-mock.com"
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

    public func user(with id: String, apiToken: String) -> SignalProducer<User, Error> {
        return SignalProducer { (observer, _) in
            self.user(with: id, apiToken: apiToken, completion: { (data, response, error) in
                if let error = error {
                    observer.send(error: error)
                }

                guard let data = data else {
                    return
                }

                let result: Result<User, Error> = self.parse(data)

                switch result {
                case let .success(user):
                    observer.send(value: user)
                case let .failure(parseError):
                    observer.send(error: parseError)
                }
            })
        }
    }

    public func parse<T>(_ data: Data) -> Result<T, Error> where T: Decodable {
        return Result<T, Error> { try JSONDecoder().decode(T.self, from: data) }
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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpMethod = method.uppercased()
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        if let token = token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }
}

public struct User: Decodable {
    let email: String
    let stepCount: Double

    enum CodingKeys: String, CodingKey {
        case email
        case stepCount = "step_count"
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        email = try values.decode(String.self, forKey: .email)
        stepCount = try values.decode(Double.self, forKey: .stepCount)
    }
}
