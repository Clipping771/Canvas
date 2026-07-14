import 'package:vinci_board/core/ports/i_auth_adapter.dart';

class GoogleWorkspaceSsoAdapter implements IAuthAdapter {
  @override
  String get providerName => 'Google Workspace SSO';

  @override
  Future<String> loginWithSSO(String domain) async {
    // TODO: Implement Google Workspace SSO logic
    throw UnimplementedError(
      'GoogleWorkspaceSsoAdapter.loginWithSSO not implemented',
    );
  }

  @override
  Future<void> logout() async {
    // TODO: Implement Google Workspace logout
    throw UnimplementedError(
      'GoogleWorkspaceSsoAdapter.logout not implemented',
    );
  }

  @override
  Future<Map<String, dynamic>?> getCurrentUser() async {
    // TODO: Implement user fetching
    return null;
  }
}
