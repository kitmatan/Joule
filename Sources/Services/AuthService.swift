import FirebaseAuth
import FirebaseCore
import Foundation
import GoogleSignIn
import UIKit

/// Google Sign-In, backing the per-user Firestore subtree.
///
/// A federated identity rather than anonymous auth because the same history has to be readable from
/// the iPhone and the Mac: an anonymous UID is per-install, so it would quietly split the log in
/// two. Google rather than Apple because Sign in with Apple requires a paid Developer Program
/// membership, which a personal team does not have.
final class AuthService: ObservableObject {
    enum State: Equatable {
        case resolving
        case signedOut
        case signedIn(userID: String)

        var userID: String? {
            if case .signedIn(let userID) = self { return userID }
            return nil
        }
    }

    @Published private(set) var state: State = .resolving

    var userEmail: String? {
        Auth.auth().currentUser?.email
    }

    var userDisplayName: String? {
        Auth.auth().currentUser?.displayName
    }

    var isSignedIn: Bool {
        if case .signedIn = state { return true }
        return false
    }

    private let alerts: AlertCenter
    private var stateHandle: AuthStateDidChangeListenerHandle?

    init(alerts: AlertCenter) {
        self.alerts = alerts
        
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
        
        // Listen to Firebase Auth state changes
        stateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            if let user = user {
                self?.state = .signedIn(userID: user.uid)
            } else {
                // If Firebase reports no user, attempt to restore previous Google Sign-In session if available
                if GIDSignIn.sharedInstance.hasPreviousSignIn() {
                    GIDSignIn.sharedInstance.restorePreviousSignIn { resultUser, error in
                        guard let resultUser, error == nil, let idToken = resultUser.idToken?.tokenString else {
                            self?.state = .signedOut
                            return
                        }
                        
                        let credential = GoogleAuthProvider.credential(
                            withIDToken: idToken,
                            accessToken: resultUser.accessToken.tokenString
                        )
                        Auth.auth().signIn(with: credential) { _, signInError in
                            if signInError != nil {
                                self?.state = .signedOut
                            }
                        }
                    }
                } else {
                    self?.state = .signedOut
                }
            }
        }
    }

    deinit {
        if let stateHandle {
            Auth.auth().removeStateDidChangeListener(stateHandle)
        }
    }

    // MARK: - Sign in

    func signIn() {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            alerts.report(failure: "Google Sign-In is not configured for this app. Enable the Google provider in the Firebase console and re-download GoogleService-Info.plist.")
            return
        }
        guard let presenter = Self.presentingViewController else {
            alerts.report(failure: "Could not find a window to present sign-in from.")
            return
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { [weak self] result, error in
            guard let self else { return }

            if let error {
                // Dismissing the sheet lands here too, and a cancellation is not worth an alert.
                if (error as NSError).code == GIDSignInError.canceled.rawValue { return }
                self.alerts.report(failure: "Sign in failed: \(error.localizedDescription)")
                return
            }

            guard let user = result?.user, let idToken = user.idToken?.tokenString else {
                self.alerts.report(failure: "Google did not return a usable identity token.")
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )
            Auth.auth().signIn(with: credential) { [weak self] _, error in
                if let error {
                    self?.alerts.report(failure: "Sign in failed: \(error.localizedDescription)")
                }
                // Success needs no handling here — the state listener publishes the new user.
            }
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        do {
            try Auth.auth().signOut()
        } catch {
            alerts.report(failure: "Sign out failed: \(error.localizedDescription)")
        }
    }

    /// Forwards the OAuth callback. The SDK usually completes in its own web session, but a redirect
    /// that comes back through the custom URL scheme has to be handed over explicitly.
    @discardableResult
    func handle(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    /// GoogleSignIn presents from UIKit, which SwiftUI does not hand out — so the key window's root
    /// controller is the way in. Works unchanged under Catalyst.
    private static var presentingViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}
