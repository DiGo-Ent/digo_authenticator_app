import 'dart:async';
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

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _selectedGroup = 'All';
  String? _copiedAccountId;
  Timer? _copyTimer;
  bool _isFabOpen = false;
  late AnimationController _fabAnimController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _copyTimer?.cancel();
    _fabAnimController.dispose();
    super.dispose();
  }

  void _toggleFab() {
    setState(() {
      _isFabOpen = !_isFabOpen;
    });
    if (_isFabOpen) {
      _fabAnimController.forward();
    } else {
      _fabAnimController.reverse();
    }
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/digo_logo.png',
                height: 44,
                width: 44,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Text(localizations.translate('app_title')),
          ],
        ),
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
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Powered by DiGo',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.0,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Speed dial options
          FadeTransition(
            opacity: _fabAnimation,
            child: ScaleTransition(
              scale: _fabAnimation,
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Scan QR option
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Material(
                          color: Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Text(
                              localizations.translate('scan_qr'),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FloatingActionButton.small(
                          heroTag: 'fab_scan',
                          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                          foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                          onPressed: () {
                            _toggleFab();
                            context.push('/scan');
                          },
                          child: const Icon(Icons.qr_code_scanner_rounded),
                        ),
                      ],
                    ),
                  ),
                  // Manual Entry option
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Material(
                          color: Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Text(
                              localizations.translate('manual_entry'),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FloatingActionButton.small(
                          heroTag: 'fab_manual',
                          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                          foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                          onPressed: () {
                            _toggleFab();
                            context.push('/add');
                          },
                          child: const Icon(Icons.keyboard_outlined),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Main FAB with animated + / × icon
          FloatingActionButton(
            heroTag: 'fab_main',
            onPressed: _toggleFab,
            child: AnimatedBuilder(
              animation: _fabAnimController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _fabAnimController.value * 0.75 * 3.14159,
                  child: Icon(_isFabOpen ? Icons.close : Icons.add),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildEmptyState(AppLocalizations localizations) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/digo_logo.png',
                height: 80,
                width: 80,
                fit: BoxFit.cover,
              ),
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
          _copyTimer?.cancel();
          setState(() {
            _copiedAccountId = account.id;
          });
          _copyTimer = Timer(const Duration(milliseconds: 1200), () {
            if (mounted) {
              setState(() {
                if (_copiedAccountId == account.id) {
                  _copiedAccountId = null;
                }
              });
            }
          });
        },
        onLongPress: () => context.push('/detail/${account.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: drag handle + account info + menu button
              Row(
                children: [
                  if (showDragHandle)
                    ReorderableDragStartListener(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  if (account.isFavorite)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.star_rounded,
                        size: 18,
                        color: Colors.amber[700],
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.issuer,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          account.accountName,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.outline),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 140),
                    onSelected: (value) {
                      if (value == 'edit') {
                        context.push('/detail/${account.id}');
                      } else if (value == 'delete') {
                        _showDeleteConfirmDialog(context, account);
                      } else if (value == 'favorite') {
                        ref.read(authenticatorProvider.notifier).toggleFavorite(account.id);
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            const Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'favorite',
                        child: Row(
                          children: [
                            Icon(
                              account.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                              size: 20,
                              color: Colors.amber[700],
                            ),
                            const SizedBox(width: 8),
                            Text(account.isFavorite ? 'Unfavorite' : 'Favorite'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                            const SizedBox(width: 8),
                            const Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (account.groupName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
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
                ),
              const SizedBox(height: 8),
              // Bottom row: OTP code + countdown/refresh
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(
                        scale: animation,
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
                    child: _copiedAccountId == account.id
                        ? Container(
                            key: const ValueKey('copied'),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                                SizedBox(width: 6),
                                Text(
                                  'Copied!',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Text(
                            formattedOtp,
                            key: const ValueKey('otp'),
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2.0,
                                ),
                          ),
                  ),
                  isTotp
                      ? SizedBox(
                          width: 32,
                          height: 32,
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

  void _showDeleteConfirmDialog(BuildContext context, OtpAccount account) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: Text('Are you sure you want to delete the account "${account.issuer} (${account.accountName})"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                ref.read(authenticatorProvider.notifier).deleteAccount(account.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${account.issuer} deleted'),
                    backgroundColor: Colors.red,
                  ),
                );
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }


}
