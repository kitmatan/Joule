import GoogleSignInSwift
import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var auth: AuthService

    /// The SDK's own button, so the Google branding is the sanctioned artwork rather than a
    /// hand-drawn imitation.
    @StateObject private var buttonViewModel = GoogleSignInButtonViewModel(
        scheme: .light,
        style: .wide,
        state: .normal
    )

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "bolt.car.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.jouleInk.gradient)

                Text("Joule.")
                    .font(.joule(.largeTitle)).bold()

                Text("Sign in to keep your charging history private to you and in sync across your iPhone, iPad and Mac.")
                    .font(.joule(.subheadline))
                    .foregroundColor(.jouleMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }

            Spacer()

            GoogleSignInButton(viewModel: buttonViewModel) {
                auth.signIn()
            }
            .frame(maxWidth: 340)
            .padding(.bottom, 40)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
