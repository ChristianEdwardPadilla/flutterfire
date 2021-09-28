import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_ui/firebase_ui.dart';

import '../auth_controller.dart';
import '../auth_flow.dart';
import '../auth_state.dart';

class AwatingPhoneNumber extends AuthState {}

class SMSCodeRequested extends AuthState {}

class PhoneVerified extends AuthState {
  final AuthCredential credential;

  PhoneVerified(this.credential);
}

class PhoneVerificationFailed extends AuthState {
  final FirebaseAuthException exception;

  PhoneVerificationFailed(this.exception);
}

class SMSCodeSent extends AuthState {
  final int? resendToken;

  SMSCodeSent(this.resendToken);
}

abstract class PhoneVerificationController extends AuthController {
  void acceptPhoneNumber(String phoneNumber);
  void verifySMSCode(String code);
}

class PhoneVerificationAuthFlow extends AuthFlow
    implements PhoneVerificationController {
  final _smsCodeCompleter = Completer<String>();

  PhoneVerificationAuthFlow({
    required FirebaseAuth auth,
    required AuthAction action,
  }) : super(auth: auth, initialState: AwatingPhoneNumber(), action: action);

  @override
  Future<void> acceptPhoneNumber(String phoneNumber) async {
    value = SMSCodeRequested();

    await auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) {
        value = PhoneVerified(credential);
        setCredential(credential);
      },
      verificationFailed: (exception) {
        value = PhoneVerificationFailed(exception);
      },
      codeSent: (String verificationId, int? resendToken) async {
        value = SMSCodeSent(resendToken);
        final code = await _smsCodeCompleter.future;
        final credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: code,
        );
        value = PhoneVerified(credential);
        setCredential(credential);
      },
      codeAutoRetrievalTimeout: (verificationId) {
        // TODO: handle this properly
        throw Exception('code autoresolution failed');
      },
    );
  }

  @override
  void verifySMSCode(String code) {
    _smsCodeCompleter.complete(code);
  }
}
