import Foundation
import NaturalLanguage

final class LanguageDetector {
    func isLikelyCode(text: String) -> Bool {
        let tagger = NLTagger(tagSchemes: [.tokenType, .language])
        tagger.string = text

        let language = tagger.dominantLanguage
        if language == nil {
            // No language detected -> often code
        }

        var bracesCount = 0
        var semicolonsCount = 0
        var equalSignsCount = 0
        var codeKeywordsCount = 0
        var syntaxTokensCount = 0

        let codePatterns = [
            "function", "var", "let", "const", "return", "if", "else", "for", "while",
            "class", "import", "from", "def", "public", "private", "static", "void",
            "int", "string", "bool", "float", "double", "export", "require", "module",
            "package", "namespace", "interface", "implements", "extends", "async", "await"
        ]

        let syntaxTokens = ["=>", "===", "!==", "!=", "&&", "||", "++", "--", "+=", "-=", "*=", "/=", "::", "->"]

        for word in text.components(separatedBy: .whitespacesAndNewlines) {
            let trimmed = word.trimmingCharacters(in: .punctuationCharacters)
            if !trimmed.isEmpty && codePatterns.contains(where: { trimmed == $0 }) {
                codeKeywordsCount += 2
            } else if !trimmed.isEmpty && codePatterns.contains(where: { trimmed.localizedCaseInsensitiveContains($0) }) {
                codeKeywordsCount += 1
            }

            for token in syntaxTokens where word.contains(token) {
                syntaxTokensCount += 1
            }
        }

        for char in text {
            if ["{", "}", "(", ")", "[", "]"].contains(char) {
                bracesCount += 1
            } else if char == ";" {
                semicolonsCount += 1
            } else if char == "=" {
                equalSignsCount += 1
            }
        }

        let lines = text.components(separatedBy: .newlines)
        var indentCounts: [Int: Int] = [:]
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            let leadingSpaces = line.prefix(while: { $0 == " " }).count
            indentCounts[leadingSpaces, default: 0] += 1
        }
        let consistentIndentation = indentCounts.values.contains(where: { $0 > 2 })

        let codeScore = bracesCount + (semicolonsCount * 2) + equalSignsCount + (codeKeywordsCount) + (syntaxTokensCount * 2) + (consistentIndentation ? 3 : 0)
        let textLength = max(1, text.count / 30)
        let isLikelyCode = codeScore > textLength || text.contains("```")
        return isLikelyCode
    }
}
