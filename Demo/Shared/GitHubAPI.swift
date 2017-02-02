import Foundation
import Moya
import Result

// MARK: - Provider setup

private func JSONResponseDataFormatter(_ data: Data) -> Data {
    do {
        let dataAsJSON = try JSONSerialization.jsonObject(with: data)
        let prettyData =  try JSONSerialization.data(withJSONObject: dataAsJSON, options: .prettyPrinted)
        return prettyData
    } catch {
        return data // fallback to original data if it can't be serialized.
    }
}

let GitHubProvider = MoyaProvider<GitHub>(plugins: [NetworkLoggerPlugin(verbose: true, responseDataFormatter: JSONResponseDataFormatter)])

// MARK: - Provider support

private extension String {
    var urlEscaped: String {
        return self.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
    }
}

public typealias StringResult =           Result<String, MoyaError>
public typealias StringAnyDictResult =    Result<[String:Any], MoyaError>
public typealias NSArrayResult =          Result<NSArray, MoyaError>

public typealias StringResultCompletion =           (StringResult) -> Void
public typealias StringAnyDictResultCompletion =    (StringAnyDictResult) -> Void
public typealias NSArrayResultCompletion =          (NSArrayResult) -> Void

public enum GitHub {
    
    case zen(StringResultCompletion)
    case userProfile(String, StringAnyDictResultCompletion)
    case userRepositories(String, NSArrayResultCompletion)
}

extension GitHub: TargetTypeWithCompletion {

    public func complete(with response: Result<Moya.Response, MoyaError>) {
        switch  self {
        case .zen(let completion):
            let result = GitHub.parseString(from: response)
            completion(result)
        case .userProfile(_, let completion):
            let result = GitHub.parseDictionary(from: response)
            completion(result)
        case .userRepositories(_, let completion):
            let result = GitHub.parseNSArray(from: response)
            completion(result)
        }
    }

    public var baseURL: URL { return URL(string: "https://api.github.com")! }
    public var path: String {
        switch self {
        case .zen(_):
            return "/zen"
        case .userProfile(let name, _):
            return "/users/\(name.urlEscaped)"
        case .userRepositories(let name, _):
            return "/users/\(name.urlEscaped)/repos"
        }
    }
    public var method: Moya.Method {
        return .get
    }
    public var parameters: [String: Any]? {
        switch self {
        case .userRepositories(_):
            return ["sort": "pushed"]
        default:
            return nil
        }
    }
    public var parameterEncoding: ParameterEncoding {
        return URLEncoding.default
    }
    public var task: Task {
        return .request
    }
    public var validate: Bool {
        switch self {
        case .zen:
            return true
        default:
            return false
        }
    }
    public var sampleData: Data {
        switch self {
        case .zen:
            return "Half measures are as bad as nothing at all.".data(using: String.Encoding.utf8)!
        case .userProfile(let name):
            return "{\"login\": \"\(name)\", \"id\": 100}".data(using: String.Encoding.utf8)!
        case .userRepositories(_):
            return "[{\"name\": \"Repo Name\"}]".data(using: String.Encoding.utf8)!
        }
    }
}

public func url(_ route: TargetType) -> String {
    return route.baseURL.appendingPathComponent(route.path).absoluteString
}

//Parsers
extension GitHub {
    
    public static func parseNSArray(from result: Result<Moya.Response, MoyaError>) -> NSArrayResult {
        do {
            let response = try result.dematerialize()
            if let json = try response.mapJSON() as? NSArray {
                // Presumably, you'd parse the JSON into a model object. This is just a demo, so we'll keep it as-is.
                return Result(value: json)
            } else {
                return Result(error: MoyaError.jsonMapping(response))
            }
        } catch let error as MoyaError {
            return Result(error: error)
        } catch {
            return Result(error: MoyaError.underlying(error))
        }
    }
    
    public static func parseString(from result: Result<Moya.Response, MoyaError>) -> StringResult {
        do {
            let response = try result.dematerialize()
            guard let string = String(data: response.data, encoding: .utf8) else {
                throw MoyaError.stringMapping(response)
            }
            return Result(value: string)
        } catch let error as MoyaError {
            return Result(error: error)
        } catch {
            return Result(error: MoyaError.underlying(error))
        }
    }
    
    public static func parseDictionary(from result: Result<Moya.Response, MoyaError>) -> StringAnyDictResult {
        do {
            let response = try result.dematerialize()
            assertionFailure("Parser for dictionary not known")
            return Result(error: MoyaError.stringMapping(response))
        } catch let error as MoyaError {
            return Result(error: error)
        } catch {
            return Result(error: MoyaError.underlying(error))
        }
    }

}
