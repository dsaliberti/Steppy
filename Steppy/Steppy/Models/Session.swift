public struct Session {
    let apiToken: String
    let userId: String
}

extension Session: Decodable {
    enum CodingKeys: String, CodingKey {
        case apiToken = "token"
        case userId = "user_id"
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        apiToken = try values.decode(String.self, forKey: .apiToken)
        userId = try values.decode(String.self, forKey: .userId)
    }
}
