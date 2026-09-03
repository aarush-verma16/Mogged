import SwiftUI

enum VercelButtonKind {
    case primary
    case secondary
}

struct VercelButtonStyle: ButtonStyle {
    var kind: VercelButtonKind = .primary
    var disabled = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.sans(14, weight: .medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, Theme.Space.x3)
            .frame(height: Theme.Space.control)
            .background(background(pressed: configuration.isPressed), in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay {
                if kind == .secondary {
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                }
            }
            .opacity(disabled ? 0.5 : (configuration.isPressed ? 0.85 : 1))
    }

    private var foreground: Color {
        switch kind {
        case .primary: return Theme.canvas
        case .secondary: return Theme.ink
        }
    }

    private func background(pressed: Bool) -> Color {
        switch kind {
        case .primary:
            return pressed ? Theme.accents7 : Color.white
        case .secondary:
            return pressed ? Theme.raised : Theme.surface
        }
    }
}

struct StatusBadge: View {
    let text: String
    let tone: Tone

    enum Tone { case idle, ready, running, warning }

    var body: some View {
        HStack(spacing: Theme.Space.x2) {
            Circle()
                .fill(dot)
                .frame(width: 8, height: 8)
            Text(text)
                .font(Theme.sans(12, weight: .medium))
                .foregroundStyle(Theme.body)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .overlay {
            Capsule().strokeBorder(Theme.border, lineWidth: 1)
        }
    }

    private var dot: Color {
        switch tone {
        case .idle: return Theme.accents3
        case .ready: return Theme.success
        case .running: return Theme.blue
        case .warning: return Theme.warning
        }
    }
}
