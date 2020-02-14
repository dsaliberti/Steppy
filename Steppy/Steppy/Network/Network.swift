import Foundation

public protocol Connectable {
    var timeoutForRequest: TimeInterval { get }
    func request(_ request: URLRequest, completion:  @escaping (Data?, URLResponse?, Error?) -> ()) -> Void
}


public final class Network: Connectable {
    public let timeoutForRequest = 30.0
    public func request(_ request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> ()) {
        URLSession.shared.dataTask(
            with: request,
            completionHandler: completion
        ).resume()
    }
}
