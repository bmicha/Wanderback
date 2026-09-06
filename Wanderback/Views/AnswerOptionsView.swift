import SwiftUI

/// Grille 4 colonnes de cartes réponse (ville + pays).
struct AnswerOptionsView: View {
    let options: [LocationCluster]
    let onSelect: (LocationCluster) -> Void

    @FocusState private var focusedOption: UUID?

    var body: some View {
        optionsContainer
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

    /// Sur iPhone en portrait, les 4 cartes ne tiennent pas sur une rangée
    /// (~85 pt chacune) : grille 2×2. Ailleurs, la rangée du design d'origine.
    @ViewBuilder
    private var optionsContainer: some View {
        if Device.isPhone {
            Grid(horizontalSpacing: 12.scaled, verticalSpacing: 12.scaled) {
                ForEach(Array(stride(from: 0, to: options.count, by: 2)), id: \.self) { row in
                    GridRow {
                        ForEach(row ..< min(row + 2, options.count), id: \.self) { index in
                            answerCard(options[index], index: index)
                        }
                    }
                }
            }
        } else {
            HStack(spacing: 24.scaled) {
                ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                    answerCard(option, index: index)
                }
            }
        }
    }

    @ViewBuilder
    private func answerCard(_ option: LocationCluster, index: Int) -> some View {
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

/// Carte réponse : surface sombre + blur, bordure 3pt ; focus = fond blanc, texte sombre, scale 1.07.
private struct AnswerCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        AnswerCardLabel(configuration: configuration)
    }

    private struct AnswerCardLabel: View {
        @Environment(\.isFocused) private var isFocused
        @State private var isHovered = false
        let configuration: ButtonStyle.Configuration

        private var isHighlighted: Bool { isFocused || isHovered || configuration.isPressed }

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
