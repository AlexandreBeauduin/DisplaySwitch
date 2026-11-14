import Testing
@testable import DisplayCore

@Suite("Localization", .serialized)
struct LocalizationTests {
    @Test func picksFirstSupportedPreferredLanguage() {
        #expect(Language.preferred(from: ["nl-BE", "fr-FR"]) == .nl)
        #expect(Language.preferred(from: ["ja-JP", "de_AT"]) == .de)
        #expect(Language.preferred(from: ["fr"]) == .fr)
        #expect(Language.preferred(from: ["ja", "zh-Hans"]) == .en)
        #expect(Language.preferred(from: []) == .en)
    }

    @Test(arguments: Language.allCases)
    func everyLanguageHasItsOwnStrings(_ language: Language) {
        let saved = L10n.language
        defer { L10n.language = saved }
        L10n.language = language
        let strings = [L10n.displays, L10n.allButMain, L10n.reconnectAll, L10n.quit,
                       L10n.lastActiveDisplay, L10n.usage, DisplayError.builtinProtected.description]
        #expect(strings.allSatisfy { !$0.isEmpty })
        if language != .en {
            L10n.language = .en
            let english = [L10n.displays, L10n.allButMain, L10n.reconnectAll, L10n.quit,
                           L10n.lastActiveDisplay, L10n.usage, DisplayError.builtinProtected.description]
            #expect(strings != english)
        }
    }

    @Test func usageMentionsEveryCommandInEveryLanguage() {
        let saved = L10n.language
        defer { L10n.language = saved }
        for language in Language.allCases {
            L10n.language = language
            for command in ["list", "off", "on", "sidecar", "on-all", "only-main", "detect", "debug"] {
                #expect(L10n.usage.contains("displayctl \(command)"), "\(language): \(command)")
            }
        }
    }
}
