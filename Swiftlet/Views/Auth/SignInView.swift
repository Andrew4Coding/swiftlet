//
//  SignInView.swift
//  Swiftlet
//

import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @Environment(AuthenticationService.self) private var authService

    @State private var animateIn = false
    @State private var floatPhase = false

    private static let privacyURL = URL(string: "https://andrew4coding.github.io/swiftlet/privacy.html")!
    private static let supportURL = URL(string: "https://andrew4coding.github.io/swiftlet/support.html")!

    private let orbs: [(emoji: String, colorHex: String, x: CGFloat, y: CGFloat, size: CGFloat)] = [
        ("🍜", "FF3B30", -118, -96, 54),
        ("🧳", "00C7BE", 122, -60, 48),
        ("💰", "34C759", -126, 96, 46),
        ("🎓", "C644FC", 116, 110, 52),
    ]

    var body: some View {
        ZStack {
            SignInSky()

            VStack(spacing: 0) {
                header
                    .padding(.top, 36)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 20)

                Spacer(minLength: 16)

                hero
                    .opacity(animateIn ? 1 : 0)
                    .scaleEffect(animateIn ? 1 : 0.92)

                Spacer(minLength: 16)

                actions
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 16)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
                animateIn = true
            }
            withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
                floatPhase = true
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text("SWIFTLET")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .italic()
                .tracking(1.5)
                .foregroundStyle(.white)

            VStack(spacing: 0) {
                Text("See your money,")
                    .foregroundStyle(.white)
                Text("swiftly")
                    .foregroundStyle(.white.opacity(0.7))
            }
            .font(.system(size: 30, weight: .semibold, design: .rounded))
            .multilineTextAlignment(.center)
        }
        .shadow(color: Color(hex: "1E5A96").opacity(0.25), radius: 8, y: 2)
        .accessibilityElement(children: .combine)
    }

    private var hero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(.white.opacity(0.18))
                .background(.ultraThinMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: 36, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0.2)], startPoint: .top, endPoint: .bottom),
                            lineWidth: 1.5
                        )
                )
                .frame(width: 190, height: 250)
                .shadow(color: Color(hex: "1E5A96").opacity(0.2), radius: 24, y: 12)

            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 128, height: 128)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
                .rotationEffect(.degrees(floatPhase ? 2 : -2))

            ForEach(orbs.indices, id: \.self) { index in
                let orb = orbs[index]
                IconBadge(iconType: .emoji, iconValue: orb.emoji, colorHex: orb.colorHex, size: orb.size)
                    .offset(x: orb.x, y: orb.y + (floatPhase ? -6 : 6) * (index.isMultiple(of: 2) ? 1 : -1))
            }
        }
        .frame(height: 300)
        .accessibilityHidden(true)
    }

    private var actions: some View {
        VStack(spacing: 12) {
            SignInButton(style: .white, cornerRadius: 25)
                .shadow(color: Color(hex: "1E5A96").opacity(0.15), radius: 10, y: 4)

            Button {
                authService.continueWithoutAccount()
            } label: {
                Text("Continue without an account")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(.white.opacity(0.55), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.8), lineWidth: 1))
                    .shadow(color: Color(hex: "1E5A96").opacity(0.12), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .environment(\.colorScheme, .light)

            HStack {
                Link("Privacy Policy", destination: Self.privacyURL)
                Spacer()
                Link("Support", destination: Self.supportURL)
            }
            .font(.footnote)
            .foregroundStyle(Color(hex: "1E3A5F").opacity(0.6))
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .padding(.bottom, 24)
    }
}

/// Sky gradient with soft drifting clouds, drawn in code so no image assets are needed.
private struct SignInSky: View {
    @State private var drift = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "5B9BD5"), Color(hex: "8EC1EA"), Color(hex: "CFE6F7")],
                    startPoint: .top,
                    endPoint: .bottom
                )

                cloud(width: size.width * 0.9, height: 120)
                    .position(x: size.width * 0.15 + (drift ? 12 : -12), y: size.height * 0.46)
                cloud(width: size.width * 0.8, height: 110)
                    .position(x: size.width * 0.95 + (drift ? -14 : 14), y: size.height * 0.36)
                cloud(width: size.width * 1.4, height: 220)
                    .position(x: size.width * 0.5, y: size.height * 0.92)
                cloud(width: size.width, height: 160)
                    .position(x: size.width * 0.1 + (drift ? 10 : -10), y: size.height * 0.8)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
        .accessibilityHidden(true)
    }

    private func cloud(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Ellipse().frame(width: width, height: height)
            Ellipse().frame(width: width * 0.55, height: height * 1.1).offset(x: -width * 0.18, y: -height * 0.3)
            Ellipse().frame(width: width * 0.45, height: height * 0.9).offset(x: width * 0.2, y: -height * 0.25)
        }
        .foregroundStyle(.white.opacity(0.75))
        .blur(radius: 28)
    }
}

#Preview {
    SignInView()
        .environment(AuthenticationService())
}
