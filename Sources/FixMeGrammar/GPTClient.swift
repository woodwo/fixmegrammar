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

    func fixGrammar(text: String, translateToEnglish: Bool, presentationMode: Bool = false) async throws -> String {
        guard !apiKey.isEmpty else { throw GPTClientError.apiKeyMissing }

        // 1) Preprocess input: mask URLs (temporarily disable RU->EN keyboard slip fix)
        let maskingResult = Self.maskURLs(in: text)
        let maskedText = maskingResult.maskedText
        let keyboardFixedText = maskedText

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let basePrompt = presentationMode
            ? "You are a presentation coach. Rephrase the text to be clear, concise, and engaging when spoken aloud during a presentation. Use active voice, simple sentence structure, and make it easy to pronounce. Only fix grammar, spelling, and improve clarity for spoken delivery. If the text is already good, return it unchanged. Do not alter placeholders of the form ⟦URL_#⟧; keep them exactly as-is. Return ONLY the text, with no explanations or meta-information."
            : "You are a helpful assistant that improves grammar and spelling. Only fix grammar and spelling issues in the text. If the text is already correct, return it unchanged. Do not alter placeholders of the form ⟦URL_#⟧; keep them exactly as-is. Return ONLY the text, with no explanations or meta-information."

        let systemPrompt = basePrompt + (translateToEnglish ? " Also translate to English if the original is in Russian." : "")

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": keyboardFixedText],
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

        // 2) Unmask URLs back into the model output
        let restored = Self.unmaskURLs(in: content, using: maskingResult.placeholders)
        return restored
    }
}

// MARK: - Pre/Post processing helpers

private extension GPTClient {
    struct URLMaskingResult {
        let maskedText: String
        let placeholders: [String: String] // placeholder -> original URL
    }

    static func maskURLs(in text: String) -> URLMaskingResult {
        // Use NSDataDetector to find links and replace them with opaque placeholders
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return URLMaskingResult(maskedText: text, placeholders: [:])
        }

        let nsText = text as NSString
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

        if matches.isEmpty {
            return URLMaskingResult(maskedText: text, placeholders: [:])
        }

        var placeholders: [String: String] = [:]
        var pieces: [String] = []
        var currentIndex = 0
        var counter = 1

        for match in matches {
            let range = match.range
            if range.location > currentIndex {
                let prefix = nsText.substring(with: NSRange(location: currentIndex, length: range.location - currentIndex))
                pieces.append(prefix)
            }

            let urlString = nsText.substring(with: range)
            let placeholder = "⟦URL_\(counter)⟧"
            counter += 1
            placeholders[placeholder] = urlString
            pieces.append(placeholder)
            currentIndex = range.location + range.length
        }

        if currentIndex < nsText.length {
            let tail = nsText.substring(from: currentIndex)
            pieces.append(tail)
        }

        let masked = pieces.joined()
        return URLMaskingResult(maskedText: masked, placeholders: placeholders)
    }

    static func unmaskURLs(in text: String, using placeholders: [String: String]) -> String {
        var result = text
        guard !placeholders.isEmpty else { return result }
        // Replace each placeholder with its original value
        for (placeholder, original) in placeholders {
            result = result.replacingOccurrences(of: placeholder, with: original)
        }
        return result
    }

    static func fixRussianKeyboardSlips(in text: String) -> String {
        // Heuristic: Convert short, Cyrillic-only words that look like English typed on RU layout
        // Criteria per word: 2..24 cyrillic chars, no latin letters; mapped word must contain at least one English vowel
        let pattern = try! NSRegularExpression(pattern: "[\\p{Cyrillic}]{2,24}")

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = pattern.matches(in: text, options: [], range: fullRange)

        if matches.isEmpty { return text }

        var mutable = text
        var offset = 0

        for match in matches {
            guard let range = Range(match.range, in: mutable) else { continue }
            let token = String(mutable[range])

            // Skip if token contains characters we don't map (safety check handled inside mapping)
            let mapped = mapRussianTokenToEnglish(token)
            if shouldReplaceRussianToken(original: token, mapped: mapped) {
                let nsRange = NSRange(range, in: mutable)
                let nsMutable = NSMutableString(string: mutable)
                nsMutable.replaceCharacters(in: nsRange, with: mapped)
                mutable = String(nsMutable)
            }
        }

        return mutable
    }

    static func shouldReplaceRussianToken(original: String, mapped: String) -> Bool {
        // Do not replace if mapping produced the same string
        if original == mapped { return false }

        // Reject if mapped contains any non-ascii letters (should be pure ascii letters/punct)
        let asciiOnly = mapped.unicodeScalars.allSatisfy { $0.isASCII }
        if !asciiOnly { return false }

        // Must contain at least one english vowel
        let vowels = Set(["a","e","i","o","u","A","E","I","O","U"])
        if !mapped.contains(where: { vowels.contains(String($0)) }) { return false }

        // Keep short to avoid mangling real Russian sentences
        if mapped.count > 24 { return false }

        return true
    }

    static func mapRussianTokenToEnglish(_ token: String) -> String {
        // RU->EN keyboard layout map (macOS RU layout to US QWERTY)
        let map: [Character: Character] = [
            // Row 1
            "ё": "`", "Ё": "~",
            "й": "q", "Й": "Q",
            "ц": "w", "Ц": "W",
            "у": "e", "У": "E",
            "к": "r", "К": "R",
            "е": "t", "Е": "T",
            "н": "y", "Н": "Y",
            "г": "u", "Г": "U",
            "ш": "i", "Ш": "I",
            "щ": "o", "Щ": "O",
            "з": "p", "З": "P",
            "х": "[", "Х": "{",
            "ъ": "]", "Ъ": "}",
            // Row 2
            "ф": "a", "Ф": "A",
            "ы": "s", "Ы": "S",
            "в": "d", "В": "D",
            "а": "f", "А": "F",
            "п": "g", "П": "G",
            "р": "h", "Р": "H",
            "о": "j", "О": "J",
            "л": "k", "Л": "K",
            "д": "l", "Д": "L",
            "ж": ";", "Ж": ":",
            "э": "'", "Э": "\"",
            // Row 3
            "я": "z", "Я": "Z",
            "ч": "x", "Ч": "X",
            "с": "c", "С": "C",
            "м": "v", "М": "V",
            "и": "b", "И": "B",
            "т": "n", "Т": "N",
            "ь": "m", "Ь": "M",
            "б": ",", "Б": "<",
            "ю": ".", "Ю": ">"
        ]

        var result = String()
        result.reserveCapacity(token.count)
        for ch in token {
            if let mapped = map[ch] {
                result.append(mapped)
            } else {
                result.append(ch)
            }
        }
        return result
    }
}
