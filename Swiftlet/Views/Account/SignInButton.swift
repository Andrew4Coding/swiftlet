//
//  SignInButton.swift
//  Swiftlet
//
//  Created by Andrew Devito Aryo on 08/09/26.
//

import AuthenticationServices
import Foundation
import SwiftUI

struct SignInButton: View {
    @Environment(AuthenticationService.self) private var authService
    @Environment(\.colorScheme) private var colorScheme

    /// Overrides the colour-scheme-based style, e.g. white on the sky-blue sign-in screen.
    var style: SignInWithAppleButton.Style?
    var cornerRadius: CGFloat = 16

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            switch result {
            case let .success(authorization):
                authService.handleAuthorization(authorization)
            case let .failure(error):
                print("Sign in with Apple failed: \(error.localizedDescription)")
            }
        }
        .signInWithAppleButtonStyle(style ?? (colorScheme == .dark ? .white : .black))
        .frame(height: 50)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
