import 'package:vinci_board/core/ports/i_auth_adapter.dart';

class MockSsoAdapter implements IAuthAdapter {
  @override
  String get providerName => 'Mock SSO (Local Testing)';

  Map<String, dynamic>? _currentUser;

  @override
  Future<String> loginWithSSO(String domain) async {
    await Future.delayed(
      const Duration(seconds: 1),
    ); // Simulate network latency

    // Simulate successful enterprise login
    _currentUser = {
      'id': 'admin_001',
      'name': 'Superintendent Chalmers',
      'email': 'chalmers@\${domain}',
      'role': 'SchoolAdmin',
      'schoolId': 'sch_simpsons_101',
    };

    return 'token_mock_sso_12345';
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = null;
  }

  @override
  Future<Map<String, dynamic>?> getCurrentUser() async {
    return _currentUser;
  }
}
