import SwiftUI
import Observation

@MainActor @Observable final class AppLanguage {
    static let shared = AppLanguage()
    var choice = UserDefaults.standard.string(forKey:"interfaceLanguage") ?? "system" {
        didSet {
            UserDefaults.standard.set(choice,forKey:"interfaceLanguage")
            if choice == "system" { UserDefaults.standard.removeObject(forKey:"AppleLanguages") }
            else { UserDefaults.standard.set([choice],forKey:"AppleLanguages") }
        }
    }
    var code:String { choice == "system" ? (Locale.preferredLanguages.first?.hasPrefix("zh") == true ? "zh-Hans":"en"):choice }
}
enum L10n {
    private static let catalog:[String:String] = {
        guard let url = AppResources.url(forResource:"AppStrings",withExtension:"json"),let data = try? Data(contentsOf:url),let values = try? JSONDecoder().decode([String:String].self,from:data) else { return [:] }
        return values
    }()
    private static let templates:[(NSRegularExpression,String)] = catalog.compactMap { key,value in
        guard key.contains("%@") else { return nil }
        let pattern = "^"+key.components(separatedBy:"%@").map(NSRegularExpression.escapedPattern(for:)).joined(separator:"(.*?)")+"$"
        guard let expression = try? NSRegularExpression(pattern:pattern) else { return nil }
        return (expression,value)
    }
    @MainActor static var code:String { AppLanguage.shared.code }
    @MainActor static func text(_ source:String)->String {
        guard code == "en" else { return source }
        if let value = catalog[source] { return value }
        for (regex,value) in templates {
            guard let match = regex.firstMatch(in:source,range:NSRange(source.startIndex...,in:source)) else { continue }
            var result = value
            for index in 1..<match.numberOfRanges {
                guard let range = Range(match.range(at:index),in:source),let marker = result.range(of:"%@") else { continue }
                result.replaceSubrange(marker,with:String(source[range]))
            }
            return result
        }
        for (key,value) in catalog where key.hasSuffix("：") && source.hasPrefix(key) { return value+source.dropFirst(key.count) }
        return source
    }
}
struct AppLanguageScope:ViewModifier {
    @State private var settings = AppLanguage.shared
    func body(content:Content)->some View { content.environment(\.locale,Locale(identifier:settings.code)) }
}
