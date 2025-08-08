import Foundation

final class GPTClient {
    private let apiKey: String = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""

    enum GPTClientError: Error, LocalizedError {
        case apiKeyMissing
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .apiKeyMissing:
                return "OpenAI API key is missing"
            case .invalidResponse:
                return "Invalid response from OpenAI API"
            }
        }
    }

    func fixGrammar(text: String, translateToEnglish: Bool) async throws -> String {
        guard !apiKey.isEmpty else { throw GPTClientError.apiKeyMissing }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemPrompt = "You are a helpful assistant that improves grammar and spelling. Only fix grammar and spelling issues in the text. If the text is already correct, return it unchanged." + (translateToEnglish ? " Also translate to English if the original is in Russian." : "")

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text],
            ],
            "temperature": 0.2
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse {
            print("API Response status: \(http.statusCode)")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let errorObj = json?["error"] as? [String: Any], let message = errorObj["message"] as? String {
            throw NSError(domain: "GPTClient", code: 0, userInfo: [NSLocalizedDescriptionKey: message])
        }

        guard
            let choices = json?["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw GPTClientError.invalidResponse
        }

        return content
    }
}
