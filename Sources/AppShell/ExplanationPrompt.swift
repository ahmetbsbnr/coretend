import Foundation

/// What CoreTend asks the Mac's own language model about an item. Only the item's place in the
/// home folder and the rule that found it are given: never a file's contents.
public enum ExplanationPrompt {
    public static func instructions(french: Bool) -> String {
        french
            ? "Tu connais bien macOS et les apps du Mac. Tu expliques en français simple, sans jargon et sans dramatiser, à quoi sert un fichier ou un dossier et quelle app l’utilise. Si tu n’es pas sûr, dis-le."
            : "You know macOS and Mac apps well. You explain in plain English, without jargon or alarm, what a file or folder is for and which app uses it. If you are not sure, say so."
    }

    public static func prompt(displayPath: String, ruleTitle: String, french: Bool) -> String {
        french
            ? "Élément : \(displayPath)\nTrouvé par la règle : \(ruleTitle)\nExplique ce que c’est."
            : "Item: \(displayPath)\nFound by the rule: \(ruleTitle)\nExplain what it is."
    }
}
