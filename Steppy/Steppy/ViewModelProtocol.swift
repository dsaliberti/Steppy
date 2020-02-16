import Foundation
import ReactiveSwift

public protocol ViewModelProtocol: AnyObject {
    associatedtype State
    associatedtype Action
    
    var state: Property<State> { get }
    
    func send(action: Action)
}
