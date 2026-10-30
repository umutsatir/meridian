import MeridianUI
import SwiftUI

/// S06: optional Sign in with Apple (ONB-6). Flow only: the button does not start a real sign-in yet.
/// TODO(account): wire ASAuthorizationController (AuthenticationServices) once the capability and
/// CloudKit/Together backend exist. The app is fully usable without an account.
struct OBAccountStep: View {
    let model: OnboardingModel
    let onNotNow: () -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isFocused) private var focused
    @State private var hovered = false

    var body: some View {
        let p = MRPalette.resolve(scheme)
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                OT("Take your flights\nwith you.").obType(.serif, 48, 500, lh: 52, tracking: -0.02).foregroundStyle(p.text1.color)
                OT("Sign in to fly with friends and keep your wallet, passport and cards in sync across your Apple devices. It's optional.")
                    .obType(.ui, 17, 400, lh: 26).foregroundStyle(p.text2.color)
                    .frame(maxWidth: 460, alignment: .leading).padding(.top, 14)
                VStack(alignment: .leading, spacing: 14) {
                    appleButton(p)
                    Button(action: onNotNow) { OT("Not now") }
                        .buttonStyle(MRButtonStyle(.tertiary)).padding(.leading, -10)
                }
                .padding(.top, 44)
                HStack(alignment: .top, spacing: 10) {
                    MRIcon(.shield, size: 14).padding(.top, 2)
                    OT("Friends see your flight status, never your task or location. Hide My Email works.")
                        .mrText(.callout)
                }
                .foregroundStyle(p.text3.color)
                .frame(maxWidth: 420, alignment: .leading).padding(.top, 20)
            }
            .frame(width: 560, alignment: .leading)
            .obAt(96, 96)

            VStack(spacing: 14) {
                togetherCard(p)
                syncCard(p)
                HStack(spacing: 12) {
                    MRIcon(.lock, size: 20).foregroundStyle(p.text2.color)
                    OT("Skipping keeps everything on this Mac. You can sign in later from Settings.")
                        .mrText(.callout).foregroundStyle(p.text2.color)
                }
                .padding(.horizontal, 22).padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .mrGlass(cornerRadius: 24, elevation: .e1)
            }
            .frame(width: 484)
            .obAt(700, 96)
        }
        .frame(width: obCanvasWidth, height: obCanvasHeight, alignment: .topLeading)
    }

    private func appleButton(_ p: MRPalette) -> some View {
        let bg: Color = p.isDark ? .white : .black
        let fg: Color = p.isDark ? .black : .white
        return Button { model.signedIn = false /* TODO(account): start Sign in with Apple */ } label: {
            HStack(spacing: 10) {
                MRIcon(.apple, size: 20)
                OT("Sign in with Apple").obType(.ui, 17, 600, lh: 17)
            }
            .foregroundStyle(fg)
            .padding(.horizontal, 24).frame(minWidth: 300).frame(height: 52)
            .background(bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .brightness(hovered ? -0.06 : 0)
            .shadow(color: .black.opacity(0.35), radius: 15, y: 10)
            .mrFocusRing(focused, cornerRadius: 14, offset: 3, color: p.accent1.color)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .accessibilityLabel(Text("Sign in with Apple", tableName: "Onboarding"))
    }

    private func togetherCard(_ p: MRPalette) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                MRIcon(.users, size: 20).foregroundStyle(p.accent1.color)
                OT("Together").obType(.ui, 15, 600, lh: 18)
                Spacer(minLength: 0)
                MRPill(String(localized: "Needs sign in", table: "Onboarding"), kind: .accent)
            }
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    MRAvatar("A", tint: MRColorToken.hex("#FFB86B"), presence: .online)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Anna").obType(.ui, 14, 600, lh: 17)
                        OT("At the gate · IST → NRT").mrText(.callout).foregroundStyle(p.text2.color)
                    }
                    Spacer(minLength: 0)
                    Text("06:12").obType(.mono, 12, 500, lh: 12).foregroundStyle(p.text3.color)
                }
                HStack(spacing: 12) {
                    MRAvatar("M", tint: MRColorToken.hex("#7ADDB2"), presence: .idle)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Mert").obType(.ui, 14, 600, lh: 17)
                        OT("Idle").mrText(.callout).foregroundStyle(p.text2.color)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(.top, 16)
        }
        .foregroundStyle(p.text1.color)
        .padding(.horizontal, 22).padding(.vertical, 20)
        .mrGlass(cornerRadius: 24, elevation: .e2)
    }

    private func syncCard(_ p: MRPalette) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                MRIcon(.cloud, size: 20).foregroundStyle(p.accent2.color)
                OT("iCloud sync").obType(.ui, 15, 600, lh: 18)
                Spacer(minLength: 0)
                MRPill(String(localized: "Mac · iPhone · iPad", table: "Onboarding"), kind: .ok)
            }
            MRProgressBar(1).padding(.top, 16)
            OT("87 tickets, 19 stamps and your cards, everywhere you sign in.")
                .mrText(.callout).foregroundStyle(p.text2.color).padding(.top, 10)
        }
        .foregroundStyle(p.text1.color)
        .padding(.horizontal, 22).padding(.vertical, 20)
        .mrGlass(cornerRadius: 24, elevation: .e2)
    }
}
