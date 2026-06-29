import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInService {
  GoogleSignInService._();
  static final GoogleSignInService instance = GoogleSignInService._();

  Future<User> signIn() async {
    await GoogleSignIn.instance.initialize();

    try {
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email', 'profile'],
      );

      final GoogleSignInAuthentication auth = account.authentication;
      final String? idToken = auth.idToken;

      if (idToken == null) {
        throw FirebaseAuthException(
          code: 'no_id_token',
          message: 'Google sign-in failed to obtain ID token.',
        );
      }

      final GoogleSignInClientAuthorization? authz = await account
          .authorizationClient
          .authorizationForScopes(const ['email', 'profile']);
      final String? accessToken = authz?.accessToken;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      final user = userCredential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'firebase_sign_in_failed',
          message: 'Firebase sign-in did not return a user.',
        );
      }

      return user;
    } on GoogleSignInException catch (e) {
      throw FirebaseAuthException(
        code: 'google_sign_in_failed',
        message: e.description ?? 'Google sign-in failed.',
      );
    }
  }
}
