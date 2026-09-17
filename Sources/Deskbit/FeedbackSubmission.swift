import Foundation

enum FeedbackSubmission {
    enum Receipt: Equatable {
        case submitted
        case activationRequired
    }

    enum Error: Swift.Error, LocalizedError {
        case emptyMessage
        case networkUnavailable
        case invalidResponse
        case rejected(statusCode: Int)
        case serviceRejected(String)

        var errorDescription: String? {
            switch self {
            case .emptyMessage:
                return "请输入反馈内容。"
            case .networkUnavailable:
                return "发送失败，请检查网络后重试。"
            case .invalidResponse:
                return "服务响应异常，请稍后重试。"
            case let .rejected(statusCode):
                return "发送失败（\(statusCode)），请稍后重试。"
            case let .serviceRejected(message):
                return message.isEmpty ? "服务未接受这次反馈，请稍后重试。" : message
            }
        }
    }

    static func makeRequest(message: String) throws -> URLRequest {
        let normalizedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedMessage.isEmpty else { throw Error.emptyMessage }
        let endpoint = URL(string: "https://formsubmit.co/ajax/tonyjianchina@gmail.com")!
        let payload = [
            "message": normalizedMessage,
            "_subject": "Deskbit 用户反馈",
            "_template": "table",
            "_captcha": "false",
            "_url": "https://github.com/tonyjianchina/Deskbit"
        ]
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        return request
    }

    static func result(
        data: Data?,
        response: URLResponse?,
        transportError: Swift.Error?
    ) -> Result<Receipt, Error> {
        if transportError != nil { return .failure(.networkUnavailable) }
        guard let response = response as? HTTPURLResponse else { return .failure(.invalidResponse) }
        guard (200..<300).contains(response.statusCode) else {
            return .failure(.rejected(statusCode: response.statusCode))
        }
        guard let data,
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .failure(.invalidResponse)
        }
        let message = payload["message"] as? String ?? ""
        let normalizedMessage = message.lowercased()
        if normalizedMessage.contains("activate your form")
            || normalizedMessage.contains("activation link")
            || normalizedMessage.contains("confirm your email") {
            return .success(.activationRequired)
        }
        let success = (payload["success"] as? Bool)
            ?? (payload["success"] as? String).map { $0.lowercased() == "true" }
        guard success == true else {
            return .failure(.serviceRejected(message))
        }
        return .success(.submitted)
    }

    static func submit(
        message: String,
        completion: @escaping (Result<Receipt, Error>) -> Void
    ) {
        let request: URLRequest
        do {
            request = try makeRequest(message: message)
        } catch let error as Error {
            completion(.failure(error))
            return
        } catch {
            completion(.failure(.invalidResponse))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            let result = result(data: data, response: response, transportError: error)
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }
}
