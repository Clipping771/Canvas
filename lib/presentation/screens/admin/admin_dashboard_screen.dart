import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vinci_board/presentation/providers/admin_provider.dart';
import 'package:vinci_board/core/theme/da_vinci_theme.dart';
import 'package:vinci_board/core/widgets/glass_container.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminState = ref.watch(adminProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Admin Command Center'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (adminState.currentUser != null)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                ref.read(adminProvider.notifier).logout();
                Navigator.pop(context); // Go back to home after logout
              },
            ),
        ],
      ),
      body: adminState.currentUser == null
          ? _buildLoginView(context, ref, adminState)
          : _buildDashboardView(context, adminState),
    );
  }

  Widget _buildLoginView(
    BuildContext context,
    WidgetRef ref,
    AdminState state,
  ) {
    return Center(
      child: GlassContainer(
        blur: 20,
        opacity: 0.1,
        color: Colors.white10,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(48.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.admin_panel_settings,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              const Text(
                'Enterprise Admin Portal',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Login via District SSO to manage licenses and compliance.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              state.isAuthenticating
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.business),
                      label: const Text('Login with Google Workspace'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        ref
                            .read(adminProvider.notifier)
                            .loginWithSSO('myschool.edu');
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardView(BuildContext context, AdminState state) {
    final school = state.currentSchool;
    if (school == null) {
      return const Center(child: Text('Error loading school data.'));
    }

    final licenseUsage = school.activeLicenses / school.maxLicenses;

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.primary,
                child: Icon(Icons.school, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    school.name,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Admin: ${state.currentUser?['name']} (${state.currentUser?['email']})',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green),
                ),
                child: Text(
                  '${school.billingTier} Tier',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
          const Text(
            'License Usage',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          GlassContainer(
            blur: 15,
            opacity: 0.05,
            color: Colors.white10,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${school.activeLicenses} Active Licenses',
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${school.maxLicenses} Max',
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: licenseUsage,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      licenseUsage > 0.9 ? Colors.red : AppColors.primary,
                    ),
                    minHeight: 12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Compliance Audit Logs (FERPA/GDPR)',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Icon(Icons.security, color: Colors.green),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: state.isLoadingLogs
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: state.auditLogs.length,
                    itemBuilder: (context, index) {
                      final log = state.auditLogs[index];
                      return Card(
                        color: Colors.white.withValues(alpha: 0.05),
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(
                            Icons.history,
                            color: AppColors.textSecondary,
                          ),
                          title: Text(
                            log.description,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            'Action: ${log.actionId} | User: ${log.userId}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          trailing: Text(
                            DateFormat('MMM d, h:mm a').format(log.timestamp),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
