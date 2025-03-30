import Foundation
import Cocoa
import NaturalLanguage

// Class to manage the clipboard functionality
class ClipboardManager {
    // Previous clipboard content to avoid reprocessing the same content
    private var previousClipboardContent: String = ""
    // Menu bar item for status indication
    private var statusItem: NSStatusItem?
    // Timer for polling the clipboard
    private var timer: Timer?
    // GPT client for processing text
    private let gptClient = GPTClient()
    
    init() {
        setupStatusItem()
        startMonitoring()
    }
    
    // Sets up the status item in the menu bar
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "📎"
        
        // Create menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Exit", action: #selector(quit), keyEquivalent: "q"))
        statusItem?.menu = menu
    }
    
    // Start monitoring the clipboard
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    // Check clipboard for changes
    private func checkClipboard() {
        guard let clipboardContent = NSPasteboard.general.string(forType: .string) else {
            return
        }
        
        // Skip if content hasn't changed
        if clipboardContent == previousClipboardContent {
            return
        }
        
        previousClipboardContent = clipboardContent
        
        // Skip if content is code
        if isCode(text: clipboardContent) {
            print("Detected code, skipping grammar check")
            return
        }
        
        // Process text with GPT
        processText(clipboardContent)
    }
    
    // Check if the text is code
    private func isCode(text: String) -> Bool {
        // Use NaturalLanguage framework to detect if content is likely code
        let tagger = NLTagger(tagSchemes: [.tokenType, .language])
        tagger.string = text
        
        // First check: language detection
        // If language is detected as something other than natural language, it's likely code
        let language = tagger.dominantLanguage
        if language == nil {
            // No language detected, could be code
            print("No language detected, might be code")
        }
        
        // Second check: code-like patterns
        var bracesCount = 0
        var semicolonsCount = 0
        var equalSignsCount = 0
        var codeKeywordsCount = 0
        var syntaxTokensCount = 0
        
        // More comprehensive code patterns detection
        let codePatterns = [
            "function", "var", "let", "const", "return", "if", "else", "for", "while",
            "class", "import", "from", "def", "public", "private", "static", "void",
            "int", "string", "bool", "float", "double", "export", "require", "module",
            "package", "namespace", "interface", "implements", "extends", "async", "await"
        ]
        
        // Syntax tokens that strongly indicate code
        let syntaxTokens = ["=>", "===", "!==", "!=", "&&", "||", "++", "--", "+=", "-=", "*=", "/=", "::", "->"]
        
        // Check for code patterns in words
        for word in text.components(separatedBy: .whitespacesAndNewlines) {
            let trimmedWord = word.trimmingCharacters(in: .punctuationCharacters)
            if !trimmedWord.isEmpty && codePatterns.contains(where: { trimmedWord == $0 }) {
                codeKeywordsCount += 2  // Exact matches weigh more
            } else if !trimmedWord.isEmpty && codePatterns.contains(where: { trimmedWord.contains($0) }) {
                codeKeywordsCount += 1
            }
            
            // Check for syntax tokens
            for token in syntaxTokens {
                if word.contains(token) {
                    syntaxTokensCount += 1
                }
            }
        }
        
        // Count braces, semicolons, and equals signs
        for char in text {
            if char == "{" || char == "}" || char == "(" || char == ")" || char == "[" || char == "]" {
                bracesCount += 1
            } else if char == ";" {
                semicolonsCount += 1
            } else if char == "=" {
                equalSignsCount += 1
            }
        }
        
        // Calculate line indentation consistency (code tends to have consistent indentation)
        let lines = text.components(separatedBy: .newlines)
        var indentCounts: [Int: Int] = [:]
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            let leadingSpaces = line.prefix(while: { $0 == " " }).count
            indentCounts[leadingSpaces, default: 0] += 1
        }
        
        // If there's consistent indentation, increase likelihood of code
        let consistentIndentation = indentCounts.values.contains(where: { $0 > 2 })
        
        // Determine if it's likely code based on weighted heuristics
        let codeScore = bracesCount + (semicolonsCount * 2) + equalSignsCount + (codeKeywordsCount * 2) + (syntaxTokensCount * 3) + (consistentIndentation ? 3 : 0)
        let textLength = max(1, text.count / 30) // Normalize by length, avoid division by zero
        
        let isLikelyCode = codeScore > textLength || text.contains("```")
        
        if isLikelyCode {
            print("Detected as code. Score: \(codeScore), Length factor: \(textLength)")
            print("Counts - Braces: \(bracesCount), Semicolons: \(semicolonsCount), Equals: \(equalSignsCount), Keywords: \(codeKeywordsCount), Syntax: \(syntaxTokensCount)")
        }
        
        return isLikelyCode
    }
    
    // Process text with GPT
    private func processText(_ text: String) {
        print("Processing text with GPT: \(text)")
        
        gptClient.fixGrammar(text: text) { [weak self] result in
            switch result {
            case .success(let fixedText):
                if fixedText != text {
                    // Text was fixed, update clipboard
                    self?.updateClipboard(with: fixedText)
                    self?.flashStatusItem()
                    print("Fixed text: \(fixedText)")
                } else {
                    print("No grammar issues found")
                }
            case .failure(let error):
                print("Error fixing grammar: \(error.localizedDescription)")
            }
        }
    }
    
    // Update clipboard with fixed text
    private func updateClipboard(with text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if !pasteboard.setString(text, forType: .string) {
            print("Failed to update clipboard with fixed text")
        } else {
            // Update previous content to avoid reprocessing
            previousClipboardContent = text
            print("Successfully updated clipboard with fixed text")
        }
    }
    
    // Flash status item to indicate text was fixed
    private func flashStatusItem() {
        let originalTitle = statusItem?.button?.title ?? "📎"
        
        statusItem?.button?.title = "✓"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.statusItem?.button?.title = originalTitle
        }
    }
    
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

// Class to interact with GPT API
class GPTClient {
    // Replace with your actual OpenAI API key or get from environment/keychain
    private let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
    
    func fixGrammar(text: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard !apiKey.isEmpty else {
            print("Error: OpenAI API key not found. Set OPENAI_API_KEY environment variable.")
            completion(.failure(NSError(domain: "GPTClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "API key not found"])))
            return
        }
        
        // Create request to OpenAI API
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Prepare request body
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "system", "content": "You are a helpful assistant that improves grammar and spelling. Only fix grammar and spelling issues in the text. If the text is already correct, return it unchanged. Do not add any additional commentary."],
                ["role": "user", "content": text]
            ],
            "temperature": 0.7
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("Error serializing request body: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }
        
        // Make API request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                print("No data received from API")
                completion(.failure(NSError(domain: "GPTClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            // Print response for debugging
            if let httpResponse = response as? HTTPURLResponse {
                print("API Response status: \(httpResponse.statusCode)")
            }
            
            // Print raw response for debugging
            if let rawResponse = String(data: data, encoding: .utf8) {
                print("Raw API response: \(rawResponse)")
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                
                // Check for API error response
                if let error = json?["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    print("API Error: \(message)")
                    completion(.failure(NSError(domain: "GPTClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "API Error: \(message)"])))
                    return
                }
                
                // Try to extract the response content
                if let choices = json?["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    print("Successfully received fixed text from API")
                    completion(.success(content))
                } else {
                    print("Failed to parse expected JSON structure. Raw JSON: \(json ?? [:])")
                    completion(.failure(NSError(domain: "GPTClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse OpenAI response"])))
                }
            } catch {
                print("JSON parsing error: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
}

// Main app entry point
let app = NSApplication.shared
let clipboardManager = ClipboardManager()
app.run() 