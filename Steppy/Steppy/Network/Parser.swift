import Foundation

struct Parser {
    public static func parse<T>(_ data: Data) -> Result<T, Error> where T: Decodable {
        return Result<T, Error> { try JSONDecoder().decode(T.self, from: data) }
    }
}
