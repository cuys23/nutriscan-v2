import 'package:flutter/material.dart';
import 'package:nutriscan/config/app_colors.dart';
import 'package:nutriscan/config/app_localizations.dart';
import 'package:nutriscan/providers/auth/cloud_backup_provider.dart';
import 'package:nutriscan/providers/payment/subscription_provider.dart';
import 'package:nutriscan/providers/theme/theme_provider.dart';
import 'package:nutriscan/services/auth/account_deletion_service.dart';
import 'package:provider/provider.dart';

/// Confirmation dialog for permanent account deletion.
///
/// Required by App Store Review Guideline 5.1.1(v). Uses a typed confirmation
/// ("DELETE") rather than a plain two-button dialog because the action is
/// irreversible and destroys cloud data.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key, required this.language});

  final String language;

  /// Shows the dialog. Resolves to `true` when the account was deleted.
  static Future<bool> show(BuildContext context, String language) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeleteAccountDialog(language: language),
    );
    return result ?? false;
  }

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isDeleting = false;
  String? _errorMessage;

  String _t(String key) => AppLocalizations.getString(key, widget.language);

  bool get _canDelete =>
      _controller.text.trim().toUpperCase() ==
      _t('delete_account_confirm_word').toUpperCase();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDelete() async {
    if (!_canDelete || _isDeleting) return;

    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });

    final result = await context.read<CloudBackupProvider>().deleteAccount(
      language: widget.language,
    );

    if (!mounted) return;

    if (result.isSuccess ||
        result.status == AccountDeletionStatus.notSignedIn) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isDeleting = false;
      _errorMessage = result.status == AccountDeletionStatus.requiresRecentLogin
          ? _t('delete_account_requires_login')
          // Append the underlying cause so a failure stays diagnosable from a
          // release/TestFlight build, where there is no console to read
          // debugPrint from and the generic copy would hide a real reason
          // (Firestore permission-denied, App Check rejection) behind a
          // network-sounding message.
          : '${_t('delete_account_failed')}\n(${result.message ?? 'unknown'})';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return PopScope(
      canPop: !_isDeleting,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color:
                  isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_forever_rounded,
                      size: 40,
                      color: AppColors.error,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    _t('delete_account'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _t('delete_account_description'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 16),

                // Active subscriptions are not cancelled by deleting the
                // account — the store owns that, so say so before deletion.
                Consumer<SubscriptionProvider>(
                  builder: (_, subscription, _) {
                    if (!subscription.hasPremiumFeatures) {
                      return const SizedBox.shrink();
                    }
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _t('delete_account_purchase_note'),
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                Text(
                  _t('delete_account_confirm_hint'),
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  enabled: !_isDeleting,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark
                        ? AppColors.backgroundDark
                        : AppColors.grey100,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppColors.error,
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _canDelete && !_isDeleting ? _handleDelete : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      disabledBackgroundColor: AppColors.error.withValues(
                        alpha: 0.3,
                      ),
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white70,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: _isDeleting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(_t('delete_account_button')),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    onPressed: _isDeleting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: textSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(_t('cancel')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
