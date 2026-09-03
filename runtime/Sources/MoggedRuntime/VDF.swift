import Foundation

enum VDFValue: Sendable, Equatable {
    case string(String)
    case table([String: VDFValue])

    var string: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var table: [String: VDFValue]? {
        if case .table(let value) = self { return value }
        return nil
    }

    func string(at keys: String...) -> String? {
        string(at: keys)
    }

    func string(at keys: [String]) -> String? {
        var current: VDFValue = self
        for key in keys {
            guard let table = current.table, let next = table[key] else { return nil }
            current = next
        }
        return current.string
    }

    func table(at keys: String...) -> [String: VDFValue]? {
        var current: VDFValue = self
        for key in keys {
            guard let table = current.table, let next = table[key] else { return nil }
            current = next
        }
        return current.table
    }
}

enum VDF {
    static func parse(_ text: String) -> [String: VDFValue] {
        var parser = Parser(text: text)
        return parser.parseTable(root: true)
    }

    static func load(from url: URL) -> [String: VDFValue]? {
        guard let text = loadString(from: url) else { return nil }
        return parse(text)
    }

    static func loadString(from url: URL) -> String? {
        if let text = try? String(contentsOf: url, encoding: .utf8) { return text }
        if let text = try? String(contentsOf: url, encoding: .utf16) { return text }
        return try? String(contentsOf: url, encoding: .isoLatin1)
    }

    private struct Parser {
        let chars: [Character]
        var i = 0

        init(text: String) {
            self.chars = Array(text)
        }

        mutating func parseTable(root: Bool) -> [String: VDFValue] {
            var table: [String: VDFValue] = [:]
            while i < chars.count {
                skipNoise()
                if i >= chars.count { break }
                if chars[i] == "}" {
                    i += 1
                    break
                }
                guard let key = readString() else { break }
                skipNoise()
                if i < chars.count, chars[i] == "{" {
                    i += 1
                    table[key] = .table(parseTable(root: false))
                } else if let value = readString() {
                    table[key] = .string(value)
                } else if root {
                    break
                } else {
                    break
                }
            }
            return table
        }

        mutating func skipNoise() {
            while i < chars.count {
                let c = chars[i]
                if c == "/" && i + 1 < chars.count && chars[i + 1] == "/" {
                    while i < chars.count, chars[i] != "\n" { i += 1 }
                    continue
                }
                if c.isWhitespace {
                    i += 1
                    continue
                }
                break
            }
        }

        mutating func readString() -> String? {
            skipNoise()
            guard i < chars.count else { return nil }
            if chars[i] == "}" { return nil }
            if chars[i] == "{" { return nil }

            if chars[i] == "\"" {
                i += 1
                var out = ""
                while i < chars.count {
                    let c = chars[i]
                    if c == "\\" && i + 1 < chars.count {
                        out.append(chars[i + 1])
                        i += 2
                        continue
                    }
                    if c == "\"" {
                        i += 1
                        return out
                    }
                    out.append(c)
                    i += 1
                }
                return out
            }

            var out = ""
            while i < chars.count {
                let c = chars[i]
                if c.isWhitespace || c == "{" || c == "}" { break }
                out.append(c)
                i += 1
            }
            return out.isEmpty ? nil : out
        }
    }
}
