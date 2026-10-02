import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInService {
  GoogleSignInService._();
  static final GoogleSignInService instance = GoogleSignInService._();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<User> signIn() async {
    final account = await _googleSignIn.signIn();
    if (account == null) {
      throw FirebaseAuthException(
        code: 'google_sign_in_failed',
        message: 'Google sign-in was cancelled by user.',
      );
    }

    final GoogleSignInAuthentication authentication =
        await account.authentication;

    // google_sign_in's `authentication` is non-null after signIn completes.
    try {
      final String? idToken = authentication.idToken;
      final String? accessToken = authentication.accessToken;

      if (idToken == null || accessToken == null) {
        throw FirebaseAuthException(
          code: 'no_id_token',
          message: 'Google sign-in failed to obtain tokens.',
        );
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final user = userCredential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'firebase_sign_in_failed',
          message: 'Firebase sign-in did not return a user.',
        );
      }

      return user;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw FirebaseAuthException(
        code: 'google_sign_in_failed',
        message: e.toString(),
      );
    }
  }
}
