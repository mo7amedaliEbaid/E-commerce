/// In-memory session (no persistence - logging in again after an app
/// restart is fine for this simple client).
class Session {
  Session._();
  static final Session instance = Session._();

  String? token;
  String? userId;
  String? firstName;

  bool get isLoggedIn => token != null && userId != null;

  void clear() {
    token = null;
    userId = null;
    firstName = null;
  }
}
