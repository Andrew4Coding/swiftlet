//
//  SignInView.swift
//  Swiftlet
//

import AuthenticationServices
import SwiftUI

private struct OnboardingSlide: Identifiable {
    struct Orb {
        let emoji: String
        let colorHex: String
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
    }

    struct Callout {
        let emoji: String
        let colorHex: String
        let title: String
        let detail: String
        let x: CGFloat
        let y: CGFloat
    }

    let id: Int
    let mascot: String
    let headline: String
    let accent: String
    let orbs: [Orb]
    let callout: Callout
}

struct SignInView: View {
    @Environment(AuthenticationService.self) private var authService

    @State private var animateIn = false
    @State private var floatPhase = false
    @State private var selection = 0
    @State private var autoAdvanceID = 0

    private static let privacyURL = URL(string: "https://andrew4coding.github.io/swiftlet/privacy.html")!
    private static let supportURL = URL(string: "https://andrew4coding.github.io/swiftlet/support.html")!
    private static let autoAdvanceInterval: Duration = .seconds(4)

    private let slides: [OnboardingSlide] = [
        OnboardingSlide(
            id: 0,
            mascot: "Mascot",
            headline: "See your money,",
            accent: "swiftly",
            orbs: [
                .init(emoji: "🍜", colorHex: "FF3B30", x: -120, y: -100, size: 52),
                .init(emoji: "🧳", colorHex: "00C7BE", x: 124, y: -70, size: 46),
                .init(emoji: "🛍️", colorHex: "FF9500", x: -128, y: 70, size: 44),
            ],
            callout: .init(emoji: "💸", colorHex: "FF3B30", title: "Spent today", detail: "Rp 45.000", x: 70, y: 118)
        ),
        OnboardingSlide(
            id: 1,
            mascot: "Mascot2",
            headline: "Every wallet,",
            accent: "in one place",
            orbs: [
                .init(emoji: "💳", colorHex: "FF2D78", x: -122, y: -96, size: 52),
                .init(emoji: "🛒", colorHex: "34C759", x: 124, y: -80, size: 46),
                .init(emoji: "☕️", colorHex: "FF9500", x: 128, y: 40, size: 42),
            ],
            callout: .init(emoji: "👛", colorHex: "34C759", title: "Cash", detail: "Rp 640.000", x: -40, y: 122)
        ),
        OnboardingSlide(
            id: 2,
            mascot: "Mascot3",
            headline: "Plan your future,",
            accent: "one step ahead",
            orbs: [
                .init(emoji: "🐷", colorHex: "3634E0", x: -124, y: -92, size: 52),
                .init(emoji: "📈", colorHex: "34C759", x: 122, y: -84, size: 46),
                .init(emoji: "🏠", colorHex: "FF9500", x: -130, y: 64, size: 44),
            ],
            callout: .init(emoji: "🔁", colorHex: "0A84FF", title: "Netflix tomorrow", detail: "Rp 186.000 · Monthly", x: 56, y: 120)
        ),
    ]

    var body: some View {
        ZStack {
            Color.ds(.ink).ignoresSafeArea()

            VStack(spacing: 0) {
                wordmark
                    .padding(.top, 36)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 20)

                ZStack {
                    slideView(slides[selection])
                        .id(selection)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.94)),
                            removal: .opacity
                        ))
                }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(swipeGesture)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 20)

                pageIndicator
                    .padding(.vertical, 16)

                actions
                    .padding(.horizontal, 24)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 16)
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
        .onChange(of: selection) { autoAdvanceID += 1 }
        .task(id: autoAdvanceID) {
            try? await Task.sleep(for: Self.autoAdvanceInterval)
            guard !Task.isCancelled else { return }
            show((selection + 1) % slides.count)
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

    private var wordmark: some View {
        Text("SWIFTLET")
            .font(.system(size: 26, weight: .heavy, design: .rounded))
            .italic()
            .tracking(1.5)
            .foregroundStyle(Color.ds(.accentFill))
    }

    private func slideView(_ slide: OnboardingSlide) -> some View {
        VStack(spacing: 0) {
            tagline(for: slide)
                .padding(.top, 10)
            Spacer(minLength: 12)
            hero(for: slide)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height),
                      abs(value.translation.width) > 40
                else { return }
                let step = value.translation.width < 0 ? 1 : -1
                show((selection + step + slides.count) % slides.count)
            }
    }

    private func show(_ index: Int) {
        withAnimation(.easeInOut(duration: 0.35)) {
            selection = index
        }
    }

    private func tagline(for slide: OnboardingSlide) -> some View {
        VStack(spacing: 0) {
            Text(slide.headline)
                .foregroundStyle(.white)
            Text(slide.accent)
                .foregroundStyle(Color.ds(.accentFill))
        }
        .dsTextStyle(.title)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    private func hero(for slide: OnboardingSlide) -> some View {
        ZStack {
            Image(slide.mascot)
                .resizable()
                .scaledToFit()
                .frame(width: 170, height: 170)
                .rotationEffect(.degrees(floatPhase ? 2 : -2))

            ForEach(slide.orbs.indices, id: \.self) { index in
                let orb = slide.orbs[index]
                IconBadge(iconType: .emoji, iconValue: orb.emoji, colorHex: orb.colorHex, size: orb.size)
                    .offset(x: orb.x, y: orb.y + (floatPhase ? -6 : 6) * (index.isMultiple(of: 2) ? 1 : -1))
            }

            calloutCard(slide.callout)
                .offset(x: slide.callout.x, y: slide.callout.y + (floatPhase ? 4 : -4))
        }
        .frame(height: 300)
        .accessibilityHidden(true)
    }

    private func calloutCard(_ callout: OnboardingSlide.Callout) -> some View {
        HStack(spacing: 10) {
            IconBadge(iconType: .emoji, iconValue: callout.emoji, colorHex: callout.colorHex, size: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(callout.title)
                    .font(.caption.weight(.semibold))
                Text(callout.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .environment(\.colorScheme, .light)
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(slides) { slide in
                Capsule()
                    .fill(slide.id == selection ? Color.ds(.accentFill) : Color.white.opacity(0.3))
                    .frame(width: slide.id == selection ? 22 : 7, height: 7)
                    .onTapGesture {
                        show(slide.id)
                    }
            }
        }
        .animation(.snappy, value: selection)
        .accessibilityElement()
        .accessibilityLabel("Page \(selection + 1) of \(slides.count)")
    }

    private var actions: some View {
        VStack(spacing: 12) {
            SignInButton(style: .white, cornerRadius: 25)

            Button {
                authService.continueWithoutAccount()
            } label: {
                Text("Continue without an account")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(.white.opacity(0.1), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
            }
            .buttonStyle(.plain)

            HStack {
                Link("Privacy Policy", destination: Self.privacyURL)
                Spacer()
                Link("Support", destination: Self.supportURL)
            }
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.7))
            .tint(.white.opacity(0.7))
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .padding(.bottom, 24)
    }
}

#Preview {
    SignInView()
        .environment(AuthenticationService())
}
