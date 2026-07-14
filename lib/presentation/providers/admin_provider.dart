import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vinci_board/core/ports/i_auth_adapter.dart';
import 'package:vinci_board/core/ports/i_compliance_adapter.dart';
import 'package:vinci_board/adapters/auth/mock_sso_adapter.dart';
import 'package:vinci_board/adapters/compliance/ferpa_gdpr_adapter.dart';
import 'package:vinci_board/core/models/admin/school_account.dart';
import 'package:vinci_board/core/models/admin/audit_log.dart';

final adminProvider = NotifierProvider<AdminNotifier, AdminState>(
  AdminNotifier.new,
);

class AdminState {
  final IAuthAdapter authAdapter;
  final IComplianceAdapter complianceAdapter;
  final bool isAuthenticating;
  final Map<String, dynamic>? currentUser;
  final SchoolAccount? currentSchool;
  final bool isLoadingLogs;
  final List<AuditLog> auditLogs;

  AdminState({
    required this.authAdapter,
    required this.complianceAdapter,
    this.isAuthenticating = false,
    this.currentUser,
    this.currentSchool,
    this.isLoadingLogs = false,
    this.auditLogs = const [],
  });

  AdminState copyWith({
    IAuthAdapter? authAdapter,
    IComplianceAdapter? complianceAdapter,
    bool? isAuthenticating,
    Map<String, dynamic>? currentUser,
    SchoolAccount? currentSchool,
    bool? isLoadingLogs,
    List<AuditLog>? auditLogs,
  }) {
    return AdminState(
      authAdapter: authAdapter ?? this.authAdapter,
      complianceAdapter: complianceAdapter ?? this.complianceAdapter,
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
      currentUser: currentUser ?? this.currentUser,
      currentSchool: currentSchool ?? this.currentSchool,
      isLoadingLogs: isLoadingLogs ?? this.isLoadingLogs,
      auditLogs: auditLogs ?? this.auditLogs,
    );
  }
}

class AdminNotifier extends Notifier<AdminState> {
  @override
  AdminState build() {
    return AdminState(
      authAdapter: MockSsoAdapter(),
      complianceAdapter: FerpaGdprAdapter(),
    );
  }

  Future<bool> loginWithSSO(String domain) async {
    state = state.copyWith(isAuthenticating: true);
    try {
      await state.authAdapter.loginWithSSO(domain);
      final user = await state.authAdapter.getCurrentUser();

      // Mock fetching the school account based on user domain/schoolId
      final school = SchoolAccount(
        id: user?['schoolId'] ?? 'unknown',
        name: 'Springfield Elementary District',
        districtId: 'dist_789',
        billingTier: 'Enterprise',
        activeLicenses: 342,
        maxLicenses: 500,
      );

      state = state.copyWith(
        isAuthenticating: false,
        currentUser: user,
        currentSchool: school,
      );

      // Fetch compliance logs automatically
      await fetchAuditLogs();

      return true;
    } catch (e) {
      state = state.copyWith(isAuthenticating: false);
      return false;
    }
  }

  Future<void> logout() async {
    await state.authAdapter.logout();
    state = state.copyWith(
      currentUser: null,
      currentSchool: null,
      auditLogs: [],
    );
  }

  Future<void> fetchAuditLogs() async {
    if (state.currentSchool == null) return;

    state = state.copyWith(isLoadingLogs: true);
    try {
      final logs = await state.complianceAdapter.fetchRecentAuditLogs(
        state.currentSchool!.id,
      );
      state = state.copyWith(isLoadingLogs: false, auditLogs: logs);
    } catch (e) {
      state = state.copyWith(isLoadingLogs: false);
    }
  }
}
