import SwiftUI

/// Grille 4 colonnes de cartes réponse (ville + pays).
struct AnswerOptionsView: View {
    let options: [LocationCluster]
    let onSelect: (LocationCluster) -> Void

    @FocusState private var focusedOption: UUID?

    var body: some View {
        HStack(spacing: 24) {
            ForEach(options) { option in
                Button {
                    onSelect(option)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(option.displayName)
                            .font(.system(size: 28, weight: .heavy))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(option.country)
                            .font(.system(size: 21))
                            .opacity(0.6)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 24)
                }
                .buttonStyle(AnswerCardButtonStyle())
                .focused($focusedOption, equals: option.id)
            }
        }
    }
}

/// Carte réponse : surface sombre + blur, bordure 3pt ; focus = fond blanc, texte sombre, scale 1.07.
private struct AnswerCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        AnswerCardLabel(configuration: configuration)
    }

    private struct AnswerCardLabel: View {
        @Environment(\.isFocused) private var isFocused
        let configuration: ButtonStyle.Configuration

        var body: some View {
            configuration.label
                .foregroundStyle(isFocused ? Theme.inkDark : .white)
                .background {
                    if isFocused {
                        RoundedRectangle(cornerRadius: 20).fill(Color.white)
                    } else {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Theme.answerSurface)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(isFocused ? Color.clear : Theme.answerBorder, lineWidth: 3)
                )
                .shadow(color: isFocused ? Theme.focusShadow : .clear, radius: 25, y: 20)
                .scaleEffect(isFocused ? 1.07 : 1.0)
                .animation(Theme.focusAnimation, value: isFocused)
        }
    }
}
