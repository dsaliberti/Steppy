extension Optional {
    public func then(_ f: (Wrapped) throws -> Void) rethrows {
        if let wrapped = self { try f(wrapped) }
    }

    func apply<T>(_ f: ((Wrapped) -> T)?) -> T? {
        return f.flatMap { self.map($0) }
    }

    public func zip<T, U>(with other: U?, _ selector: (Wrapped, U) -> T) -> T? {
        guard let this = self, let other = other else {
            return nil
        }
        return selector(this, other)
    }

    public func defaultTo(_ default: Wrapped) -> Wrapped {
        guard let self = self else {
            return `default`
        }
        return self
    }
}

extension Optional where Wrapped: Collection {
    public var isEmpty: Bool {
        return self?.isEmpty ?? true
    }

    public var isNotEmpty: Bool {
        return !isEmpty
    }
}
