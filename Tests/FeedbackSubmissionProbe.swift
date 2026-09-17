import Foundation

@main
struct FeedbackSubmissionProbe {
    static func main() throws {
        let request = try FeedbackSubmission.makeRequest(message: "希望增加搜索功能")

        guard request.url?.absoluteString == "https://formsubmit.co/ajax/tonyjianchina@gmail.com",
              request.httpMethod == "POST",
              request.value(forHTTPHeaderField: "Content-Type") == "application/json",
              request.value(forHTTPHeaderField: "Accept") == "application/json",
              request.value(forHTTPHeaderField: "Referer") == "https://github.com/tonyjianchina/Deskbit",
              request.value(forHTTPHeaderField: "Origin") == "https://github.com",
              let body = request.httpBody,
              let payload = try JSONSerialization.jsonObject(with: body) as? [String: String],
              payload["message"] == "希望增加搜索功能",
              payload["app_version"] == nil,
              payload["system_version"] == nil,
              payload["_subject"] == "Deskbit 用户反馈",
              payload["_captcha"] == "false",
              payload["_url"] == "https://github.com/tonyjianchina/Deskbit",
              !request.url!.absoluteString.contains("mailto:") else { exit(1) }

        do {
            _ = try FeedbackSubmission.makeRequest(message: "  \n ")
            exit(2)
        } catch FeedbackSubmission.Error.emptyMessage {
            // Expected: blank feedback must never create a network request.
        } catch {
            exit(3)
        }

        let rejectedResponse = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        let rejectedBody = Data(#"{"success":"false","message":"Submission rejected"}"#.utf8)
        switch FeedbackSubmission.result(data: rejectedBody, response: rejectedResponse, transportError: nil) {
        case let .failure(.serviceRejected(message)) where message == "Submission rejected":
            break
        default:
            exit(4)
        }

        let activationBody = Data(#"{"success":"true","message":"Please activate your form from the confirmation email"}"#.utf8)
        switch FeedbackSubmission.result(data: activationBody, response: rejectedResponse, transportError: nil) {
        case .success(.activationRequired):
            break
        default:
            exit(5)
        }

        let liveActivationBody = Data(#"{"success":"false","message":"This form needs Activation. We've sent you an email containing an 'Activate Form' link. Just click it and your form will be actived!"}"#.utf8)
        switch FeedbackSubmission.result(data: liveActivationBody, response: rejectedResponse, transportError: nil) {
        case .success(.activationRequired):
            break
        default:
            exit(6)
        }

        print("feedback request: pass")
    }
}
