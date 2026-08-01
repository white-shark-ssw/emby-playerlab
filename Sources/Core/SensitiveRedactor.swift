import Foundation

enum SensitiveRedactor {
    private static let sensitiveNames = [
        "api_key", "apikey", "token", "access_token", "accesstoken",
        "signature", "sign", "auth", "authorization", "cookie", "expires"
    ]

    static func redact(_ text: String) -> String {
        var output = text
        if let range = output.range(of: "http", options: .caseInsensitive),
           let url = URL(string: String(output[range.lowerBound...])),
           let redacted = redact(url: url) {
            output.replaceSubrange(range.lowerBound..., with: redacted)
        }

        for name in sensitiveNames {
            let pattern = "(?i)(\(NSRegularExpression.escapedPattern(for: name))\\s*[:=]\\s*)([^\\s,&]+)"
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let fullRange = NSRange(output.startIndex..., in: output)
            output = regex.stringByReplacingMatches(in: output, range: fullRange, withTemplate: "$1<redacted>")
        }
        return output
    }

    static func redact(url: URL) -> String? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        components.queryItems = components.queryItems?.map { item in
            let lower = item.name.lowercased()
            if sensitiveNames.contains(where: { lower.contains($0) }) {
                return URLQueryItem(name: item.name, value: "<redacted>")
            }
            return item
        }
        return components.string
    }
}
