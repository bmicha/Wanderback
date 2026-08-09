import SwiftUI

/// Grille 4 colonnes de cartes réponse (ville + pays).
struct AnswerOptionsView: View {
    let options: [LocationCluster]
    let onSelect: (LocationCluster) -> Void

    @FocusState private var focusedOption: UUID?

    var body: some View {
        HStack(spacing: 24.scaled) {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                Button {
                    onSelect(option)
                } label: {
                    VStack(alignment: .leading, spacing: 6.scaled) {
                        Text(option.displayName)
                            .font(.system(size: 28.scaled, weight: .heavy))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(option.country)
                            .font(.system(size: 21.scaled))
                            .opacity(0.6)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28.scaled)
                    .padding(.vertical, 24.scaled)
                }
                .buttonStyle(AnswerCardButtonStyle())
                .macFocusable()
                .focused($focusedOption, equals: option.id)
                .macFocusOnHover($focusedOption, equals: option.id)
                .macKeyboardShortcut(Character("\(index + 1)"))
            }
        }
        #if os(macOS)
        .macMoveCommand { direction in
            guard let currentIndex = options.firstIndex(where: { $0.id == focusedOption }) else { return }
            switch direction {
            case .left where currentIndex > 0:
                focusedOption = options[currentIndex - 1].id
            case .right where currentIndex < options.count - 1:
                focusedOption = options[currentIndex + 1].id
            default:
                break
            }
        }
        // Focus initial sur la première carte, refait à chaque nouveau round
        // (les options changent mais la vue garde son identité structurelle).
        .onChange(of: options.map(\.id), initial: true) { _, _ in
            focusedOption = options.first?.id
        }
        .macShortcutAction(.return) {
            if let option = options.first(where: { $0.id == focusedOption }) {
                onSelect(option)
            }
        }
        #endif
    }
}

/// Carte réponse : surface sombre + blur, bordure 3pt ; focus = fond blanc, texte sombre, scale 1.07.
private struct AnswerCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        AnswerCardLabel(configuration: configuration)
    }

    private struct AnswerCardLabel: View {
        @Environment(\.isFocused) private var isFocused
        @State private var isHovered = false
        let configuration: ButtonStyle.Configuration

        private var isHighlighted: Bool { isFocused || isHovered }

        var body: some View {
            configuration.label
                .foregroundStyle(isHighlighted ? Theme.inkDark : .white)
                .background {
                    if isHighlighted {
                        RoundedRectangle(cornerRadius: 20.scaled).fill(Color.white)
                    } else {
                        RoundedRectangle(cornerRadius: 20.scaled)
                            .fill(Theme.answerSurface)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20.scaled))
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 20.scaled)
                        .strokeBorder(isHighlighted ? Color.clear : Theme.answerBorder, lineWidth: 3)
                )
                .shadow(color: isHighlighted ? Theme.focusShadow : .clear, radius: 25, y: 20)
                .scaleEffect(isHighlighted ? 1.07 : 1.0)
                .animation(Theme.focusAnimation, value: isHighlighted)
                #if os(macOS)
                .onHover { isHovered = $0 }
                #endif
        }
    }
}
