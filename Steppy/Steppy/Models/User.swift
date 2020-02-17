public struct User {
    let email: String?
    let stepCount: Double
}

extension User: Decodable {
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        email = try values.decodeIfPresent(String.self, forKey: .email)
        stepCount = try values.decode(Double.self, forKey: .stepCount)
    }
    
    enum CodingKeys: String, CodingKey {
        case email
        case stepCount = "step_count"
    }
}
