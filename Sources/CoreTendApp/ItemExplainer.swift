import SwiftUI
import AppShell
import DesignSystem
#if canImport(FoundationModels)
import FoundationModels
#endif

/// An explanation the Mac's own language model wrote about an item. Shown as help, never as a
/// guarantee: the model can be wrong, and the page says so. What a move to the Trash does is not
/// asked of the model (tried: it reassures every time); the sheet shows the rule's own words.
struct ItemExplanation: Equatable {
    let what: String
    let app: String
}

#if canImport(FoundationModels)
@available(macOS 26.0, *)
@Generable
private struct GeneratedExplanation {
    @Guide(description: "What this file or folder is and what it is used for, in two short sentences.")
    var what: String
    @Guide(description: "The app or part of macOS that uses it, or 'unknown'.")
    var app: String
}
#endif

/// Apple Intelligence on this Mac (macOS 26 or later). Nothing is sent anywhere.
enum ItemExplainer {
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    static func explain(displayPath: String, ruleTitle: String, french: Bool) async throws -> ItemExplanation {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let session = LanguageModelSession(instructions: ExplanationPrompt.instructions(french: french))
            let response = try await session.respond(to: ExplanationPrompt.prompt(displayPath: displayPath, ruleTitle: ruleTitle, french: french),
                                                     generating: GeneratedExplanation.self)
            return ItemExplanation(what: response.content.what, app: response.content.app)
        }
        #endif
        throw CocoaError(.featureUnsupported)
    }
}

/// The sheet that asks, waits and shows the explanation.
struct ItemExplanationSheet: View {
    let displayPath: String
    let ruleTitle: String
    /// The rule's own explanation of what a move to the Trash means for this kind of item.
    let ruleExplanation: String
    let french: Bool
    let close: () -> Void
    @State private var explanation: ItemExplanation?
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(copy("explain.title")).font(CoreTendTypography.pageTitle).foregroundStyle(Palette.ink.color)
            Text(displayPath).font(CoreTendTypography.caption.monospaced()).foregroundStyle(Palette.secondaryInk.color)
                .lineLimit(2).truncationMode(.middle).textSelection(.enabled)
            if let explanation {
                fact(copy("explain.what"), explanation.what)
                fact(copy("explain.app"), explanation.app)
            } else if failed {
                SerreBanner(.partial, title: copy("explain.failed"))
            } else {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(copy("explain.thinking")).font(CoreTendTypography.body).foregroundStyle(Palette.secondaryInk.color)
                }
            }
            if !ruleExplanation.isEmpty { fact(copy("explain.ifMoved"), ruleExplanation) }
            Text(copy("explain.caveat")).font(CoreTendTypography.caption).foregroundStyle(Palette.tertiaryInk.color)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(copy("common.close")) { close() }.buttonStyle(.serre(.primary)).keyboardShortcut(.cancelAction)
            }
        }
        .padding(24).frame(width: 520)
        .background(Palette.canvas.color)
        .task {
            do { explanation = try await ItemExplainer.explain(displayPath: displayPath, ruleTitle: ruleTitle, french: french) }
            catch { failed = true }
        }
    }

    private func fact(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(CoreTendTypography.body.weight(.semibold)).foregroundStyle(Palette.ink.color)
            Text(text).font(CoreTendTypography.body).foregroundStyle(Palette.secondaryInk.color)
                .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
        }
    }

    private func copy(_ key: String) -> String { ProductCopy.value(for: key, french: french) }
}
