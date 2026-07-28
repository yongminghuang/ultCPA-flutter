final class AccountSafetySnapshot {
  const AccountSafetySnapshot({required this.isLoggedIn, required this.phone});

  final bool isLoggedIn;
  final String phone;
}

enum AccountSafetyResult { deactivated }
