import 'package:vinci_board/core/models/admin/audit_log.dart';

/// Port interface for FERPA/GDPR compliance operations.
///
/// ## PII Masking Contract ([maskPii])
/// Implementations MUST mask, at minimum, the following patterns:
/// - Email addresses → `[REDACTED EMAIL]`
/// - Phone numbers (US format) → `[REDACTED PHONE]`
/// - Full names adjacent to institutional identifiers → `[REDACTED NAME]`
///
/// Implementations MUST NOT return the original [rawData] string unmodified
/// if it contains detectable PII. Returning raw data silently is a compliance
/// violation. If an implementation cannot determine whether PII is present,
/// it must err on the side of masking.
///
/// [maskPii] is synchronous and must not perform I/O or network calls.
/// It must be safe to call on the UI thread.
///
/// ## Audit Log Contract ([logAction], [fetchRecentAuditLogs])
/// - [logAction] must persist the log entry before returning. In-memory-only
///   implementations are not compliant for production use.
/// - [logAction] must apply [maskPii] to [description] before persisting.
/// - [fetchRecentAuditLogs] throws [ComplianceException] on storage failure.
///   Returns an empty list (not null) when no logs exist for [schoolId].
abstract class IComplianceAdapter {
  /// Masks Personally Identifiable Information (PII) from [rawData] to comply
  /// with FERPA/GDPR. See class-level documentation for the masking contract.
  ///
  /// Must not return [rawData] unmodified if PII is detected.
  /// Must not throw under any input — returns the best-effort masked string.
  String maskPii(String rawData);

  /// Records an auditable action to the compliance log.
  ///
  /// [description] is automatically masked via [maskPii] before persistence.
  /// Returns the persisted [AuditLog] entry on success.
  /// Throws [ComplianceException] if the entry cannot be persisted.
  Future<AuditLog> logAction({
    required String actionId,
    required String userId,
    required String description,
  });

  /// Retrieves recent audit logs for [schoolId].
  ///
  /// Returns an empty list when no logs exist. Never returns null.
  /// Throws [ComplianceException] on storage or network failure.
  Future<List<AuditLog>> fetchRecentAuditLogs(String schoolId);
}
