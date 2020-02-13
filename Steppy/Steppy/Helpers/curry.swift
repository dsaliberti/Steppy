public func curry<A, B, C>(_ function: @escaping (A, B) -> C) -> (A) -> (B) -> C {
	return { (a: A) -> (B) -> C in { (b: B) -> C in function(a, b) } }
}

public func curry<A, B, C, D>(_ function: @escaping (A, B, C) -> D) -> (A) -> (B) -> (C) -> D {
	return { (a: A) -> (B) -> (C) -> D in { (b: B) -> (C) -> D in { (c: C) -> D in function(a, b, c) } } }
}

public func curry<A, B, C, D, E>(_ function: @escaping (A, B, C, D) -> E) -> (A) -> (B) -> (C) -> (D) -> E {
    return { (a: A) -> (B) -> (C) -> (D) -> E in { (b: B) -> (C) -> (D) -> E in { (c: C) -> (D) -> E in { (d: D) -> E in function(a, b, c, d) } } } }
}

public func uncurry<A, B, C>(_ f: @escaping (A) -> (B) -> C) -> (A, B) -> C {
    return { a, b in f(a)(b) }
}

public func uncurry<A, B, C, D>(_ f: @escaping (A) -> (B) -> (C) -> D) -> (A, B, C) -> D {
	return { a, b, c in f(a)(b)(c) }
}

public func flip <A, B, C>(_ f: @escaping (A) -> (B) -> C) -> (B) -> (A) -> C {
    return { a in { b in f(b)(a) } }
}

public func flip <A, B, C, D>(_ f: @escaping (A) -> (B) -> (C) -> D) -> (C) -> (B) -> (A) -> D {
    return { a in { b in { c in f(c)(b)(a) } } }
}

public func flip <A, B, C, D, E>(_ f: @escaping (A) -> (B) -> (C) -> (D) -> E) -> (D) -> (C) -> (B) -> (A) -> E {
    return { a in { b in { c in { d in f(d)(c)(b)(a) } } } }
}

public func flip <A, C>(_ f: @escaping (A) -> () -> C) -> () -> (A) -> C {
    return { { a in f(a)() } }
}

public func invert<A, B, C>(_ f: @escaping (A, B) -> C) -> (B, A) -> C {
    return { (b: B, a: A) -> C in f(a, b) }
}

public func invert<A, B, C, D>(_ f: @escaping (A, B, C) -> D) -> (C, B, A) -> D {
    return { (c: C, b: B, a: A) -> D in f(a, b, c) }
}
