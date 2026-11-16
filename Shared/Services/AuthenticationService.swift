//
//  AuthenticationService.swift
//  Swiftlet
//

import AuthenticationServices
import Foundation
import Observation

@Observable
final class AuthenticationService {
    enum State: Equatable {
        case signedOut
        case signedIn(userID: String, displayName: String?)
        case localOnly
    }

    private static let userIDKey = "appleUserIdentifier"
    private static let displayNameKey = "appleDisplayName"
    private static let localOnlyKey = "usesAppWithoutAccount"

    private(set) var state: State

    init() {
        if let userID = UserDefaults.standard.string(forKey: Self.userIDKey) {
            state = .signedIn(userID: userID, displayName: UserDefaults.standard.string(forKey: Self.displayNameKey))
            verifyCredentialState(for: userID)
        } else if UserDefaults.standard.bool(forKey: Self.localOnlyKey) {
            state = .localOnly
        } else {
            state = .signedOut
        }
    }

    func continueWithoutAccount() {
        UserDefaults.standard.set(true, forKey: Self.localOnlyKey)
        state = .localOnly
    }

    private func verifyCredentialState(for userID: String) {
        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { [weak self] credentialState, _ in
            switch credentialState {
            case .revoked, .notFound:
                DispatchQueue.main.async { self?.signOut() }
            default:
                break
            }
        }
    }

    /// Stores the user identifier and (first sign-in only) the name from a successful authorization.
    func handleAuthorization(_ authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }

        let userID = credential.user
        // Apple supplies fullName only on the first authorization; reuse the stored name afterwards.
        let newName = credential.fullName?.formatted()
        let displayName = (newName?.isEmpty == false ? newName : nil)
            ?? UserDefaults.standard.string(forKey: Self.displayNameKey)

        UserDefaults.standard.set(userID, forKey: Self.userIDKey)
        UserDefaults.standard.removeObject(forKey: Self.localOnlyKey)
        if let displayName {
            UserDefaults.standard.set(displayName, forKey: Self.displayNameKey)
        }

        state = .signedIn(userID: userID, displayName: displayName)
    }

    func signOut() {
        UserDefaults.standard.removeObject(forKey: Self.userIDKey)
        UserDefaults.standard.removeObject(forKey: Self.displayNameKey)
        UserDefaults.standard.removeObject(forKey: Self.localOnlyKey)
        state = .signedOut
    }
}
