import AppKit
import CoreText
import Foundation

enum GeistFonts {
    static func register() {
        let names = [
            "Geist-Regular",
            "Geist-Medium",
            "Geist-SemiBold",
            "GeistMono-Regular",
            "GeistMono-Medium",
        ]
        for name in names {
            guard let url = fontURL(name) else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    private static func fontURL(_ name: String) -> URL? {
        if let url = Bundle.module.url(forResource: name, withExtension: "ttf") {
            return url
        }
        if let url = Bundle.main.url(forResource: name, withExtension: "ttf") {
            return url
        }
        if let url = Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts") {
            return url
        }
        return nil
    }
}
