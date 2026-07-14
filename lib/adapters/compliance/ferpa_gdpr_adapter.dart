import 'package:vinci_board/core/ports/i_compliance_adapter.dart';
import 'package:vinci_board/core/models/admin/audit_log.dart';

class FerpaGdprAdapter implements IComplianceAdapter {
  @override
  String maskPii(String rawData) {
    // Basic regex masking for PII like Emails and Phone numbers (for demonstration)
    String masked = rawData.replaceAll(
      RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
      '[REDACTED EMAIL]',
    );
    masked = masked.replaceAll(
      RegExp(r'\b\d{3}[-.]?\d{3}[-.]?\d{4}\b'),
      '[REDACTED PHONE]',
    );
    return masked;
  }

  @override
  Future<AuditLog> logAction({
    required String actionId,
    required String userId,
    required String description,
  }) async {
    // In production, this would securely persist to an immutable ledger
    return AuditLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      actionId: actionId,
      userId: userId,
      description: maskPii(description),
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<List<AuditLog>> fetchRecentAuditLogs(String schoolId) async {
    await Future.delayed(
      const Duration(milliseconds: 800),
    ); // Simulate network latency

    // Mock audit logs
    return [
      AuditLog(
        id: 'log_001',
        actionId: 'sso_login',
        userId: 'admin_001',
        description: 'Superintendent Chalmers logged in via SSO',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      AuditLog(
        id: 'log_002',
        actionId: 'pii_export',
        userId: 'admin_001',
        description:
            'Exported student analytics for class Math-101. PII was masked.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
      ),
      AuditLog(
        id: 'log_003',
        actionId: 'billing_update',
        userId: 'system',
        description: 'Automatically renewed 300 Enterprise licenses',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }
}
