import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/models/otp_account.dart';
import '../providers/authenticator_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedGroup = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authenticatorProvider);
    final localizations = AppLocalizations.of(context);

    // Apply search filter
    final filteredAccounts = state.accounts.where((account) {
      final matchesSearch = account.accountName.toLowerCase().contains(state.searchQuery.toLowerCase()) ||
          account.issuer.toLowerCase().contains(state.searchQuery.toLowerCase());
      if (!matchesSearch) return false;

      if (_selectedGroup == 'All') return true;
      if (_selectedGroup == 'Favorites') return account.isFavorite;
      return account.groupName == _selectedGroup;
    }).toList();

    // Get list of unique groups (excluding empty)
    final groups = {'All', 'Favorites'};
    for (final account in state.accounts) {
      if (account.groupName.isNotEmpty) {
        groups.add(account.groupName);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.translate('app_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: localizations.translate('search_placeholder'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(authenticatorProvider.notifier).setSearchQuery('');
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) {
                    ref.read(authenticatorProvider.notifier).setSearchQuery(val);
                  },
                ),
              ),

              // Group Filtering Chips
              if (groups.length > 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: groups.map((group) {
                        final isSelected = _selectedGroup == group;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(group),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedGroup = group;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

              // OTP Accounts List
              Expanded(
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredAccounts.isEmpty
                        ? _buildEmptyState(localizations)
                        : ReorderableListView.builder(
                            itemCount: filteredAccounts.length,
                            buildDefaultDragHandles: false,
                            onReorderItem: (oldIndex, newIndex) {
                              ref.read(authenticatorProvider.notifier).reorderAccounts(
                                    oldIndex,
                                    newIndex,
                                    adjustForRemoval: false,
                                  );
                            },
                            itemBuilder: (context, index) {
                              final account = filteredAccounts[index];
                              final otp = state.currentOtps[account.id] ?? '------';
                              final progress = state.otpProgress[account.id] ?? 1.0;
                              final remaining = state.otpSecondsRemaining[account.id] ?? 0;

                              return _buildAccountTile(
                                key: ValueKey(account.id),
                                account: account,
                                otp: otp,
                                progress: progress,
                                remaining: remaining,
                                localizations: localizations,
                                index: index,
                                showDragHandle: state.searchQuery.isEmpty,
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAccountMenu(context, localizations),
        icon: const Icon(Icons.add),
        label: Text(localizations.translate('add_account')),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations localizations) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.phonelink_lock_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              localizations.translate('no_accounts'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountTile({
    required Key key,
    required OtpAccount account,
    required String otp,
    required double progress,
    required int remaining,
    required AppLocalizations localizations,
    required int index,
    required bool showDragHandle,
  }) {
    // Format OTP code to show space between first and second half (e.g. 123 456)
    String formattedOtp = otp;
    if (otp.length == 6) {
      formattedOtp = '${otp.substring(0, 3)} ${otp.substring(3)}';
    } else if (otp.length == 8) {
      formattedOtp = '${otp.substring(0, 4)} ${otp.substring(4)}';
    }

    final isTotp = account.type == 'totp';
    final isCritical = isTotp && remaining <= 5;
    final primaryColor = isCritical ? Colors.red : Theme.of(context).colorScheme.primary;

    return Card(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Clipboard.setData(ClipboardData(text: otp));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.translate('otp_copied')),
              duration: const Duration(seconds: 1),
            ),
          );
        },
        onLongPress: () => context.push('/detail/${account.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (showDragHandle)
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              // Icon & Account details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (account.isFavorite)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(
                              Icons.star_rounded,
                              size: 18,
                              color: Colors.amber[700],
                            ),
                          ),
                        Text(
                          account.issuer,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      account.accountName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    if (account.groupName.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          account.groupName,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSecondaryContainer,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // OTP Code + Countdown Circle or HOTP Refresh Button
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formattedOtp,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                  ),
                  const SizedBox(width: 16),
                  isTotp
                      ? SizedBox(
                          width: 28,
                          height: 28,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 3,
                                color: primaryColor,
                                backgroundColor: Theme.of(context).colorScheme.outlineVariant,
                              ),
                              Text(
                                remaining.toString(),
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                              ),
                            ],
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          onPressed: () {
                            ref.read(authenticatorProvider.notifier).incrementHotpCounter(account.id);
                          },
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddAccountMenu(BuildContext context, AppLocalizations localizations) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.qr_code_scanner_rounded),
                title: Text(localizations.translate('scan_qr')),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/scan');
                },
              ),
              ListTile(
                leading: const Icon(Icons.keyboard_outlined),
                title: Text(localizations.translate('manual_entry')),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/add');
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
