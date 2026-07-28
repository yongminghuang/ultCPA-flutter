final class AccountProfileSnapshot {
  const AccountProfileSnapshot({
    required this.isLoggedIn,
    required this.userId,
    required this.nickname,
    required this.avatar,
  });

  final bool isLoggedIn;
  final String userId;
  final String nickname;
  final String avatar;
}

enum AccountProfileResult { signedOut }
