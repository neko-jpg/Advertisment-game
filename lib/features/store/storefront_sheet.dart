import 'dart:io';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';

import '../../monetization/product_catalog.dart';
import '../../monetization/storefront_service.dart';
import '../../services/player_wallet.dart';

Future<void> showStorefrontSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const _StorefrontSheet(),
  );
}

class _StorefrontSheet extends StatelessWidget {
  const _StorefrontSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = context.watch<StorefrontService>();
    final wallet = context.watch<PlayerWallet>();
    final products = store.availableProducts;
    final productMap = <String, ProductDetails>{
      for (final product in products) product.id: product,
    };

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.85,
      minChildSize: 0.5,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Premium Shop',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                wallet.adsRemoved
                    ? 'Ads are already disabled. Thank you for supporting the game!'
                    : 'Remove interruptions, stock up on coins, and keep momentum between runs.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 16),
              _WalletSummary(wallet: wallet),
              if (store.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    store.errorMessage!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: ProductCatalog.catalog.length,
                  itemBuilder: (context, index) {
                    final config = ProductCatalog.catalog[index];
                    final details = productMap[config.id];
                    return _ProductTile(
                      config: config,
                      details: details,
                      loading: store.loading,
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          store.loading ? null : () => store.refreshProducts(),
                      child: const Text('Refresh'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          store.restoreInProgress
                              ? null
                              : () => store.restorePurchases(),
                      child: Text(
                        Platform.isIOS ? 'Restore purchases' : 'Restore',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

class _WalletSummary extends StatelessWidget {
  const _WalletSummary({required this.wallet});

  final PlayerWallet wallet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final multiplier = wallet.coinMultiplier;
    final multiplierActive = multiplier > 1.0;
    final remaining = wallet.coinMultiplierRemaining;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Coins: ${wallet.totalCoins}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            multiplierActive
                ? 'Coin boost active: x${multiplier.toStringAsFixed(1)}'
                : 'Coin multiplier: x1.0',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: multiplierActive ? Colors.amberAccent : Colors.white70,
            ),
          ),
          if (multiplierActive && remaining != null)
            Text(
              'Expires in ${_formatDuration(remaining)}',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
            ),
          const SizedBox(height: 6),
          Text(
            wallet.adsRemoved
                ? 'Ads are disabled for this account.'
                : 'Upgrade to remove interstitial and banner ads.',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) {
      return '0m';
    }
    if (duration.inDays >= 1) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    }
    if (duration.inHours >= 1) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
    if (duration.inMinutes >= 1) {
      return '${duration.inMinutes}m';
    }
    return '${duration.inSeconds}s';
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.config,
    required this.details,
    required this.loading,
  });

  final MonetizationProduct config;
  final ProductDetails? details;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final store = context.read<StorefrontService>();
    final wallet = context.watch<PlayerWallet>();
    final theme = Theme.of(context);
    final bool isOwned =
        config.kind == MonetizationProductKind.removeAds && wallet.adsRemoved;
    final bool unavailable = details == null;

    final VoidCallback? action;
    if (isOwned || loading) {
      action = null;
    } else if (unavailable) {
      action = () => store.refreshProducts();
    } else {
      action = () => store.buyProduct(details!);
    }

    return Card(
      color: Colors.deepPurple.withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _titleFor(config),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _descriptionFor(config),
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  unavailable ? 'Not available' : details!.price,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: unavailable ? Colors.white38 : Colors.white,
                  ),
                ),
                FilledButton(
                  onPressed: action,
                  child: Text(
                    isOwned
                        ? 'Owned'
                        : unavailable
                        ? 'Retry'
                        : 'Purchase',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _titleFor(MonetizationProduct product) {
    switch (product.kind) {
      case MonetizationProductKind.removeAds:
        return 'Remove all ads';
      case MonetizationProductKind.coinBundle:
        final amount = product.coinReward ?? 0;
        return 'Coin bundle (+$amount)';
      case MonetizationProductKind.coinMultiplier:
        final multiplier = product.coinMultiplier ?? 1.0;
        return 'Coin booster x${multiplier.toStringAsFixed(1)}';
    }
  }

  String _descriptionFor(MonetizationProduct product) {
    switch (product.kind) {
      case MonetizationProductKind.removeAds:
        return 'Skip interstitial and banner ads entirely for faster sessions.';
      case MonetizationProductKind.coinBundle:
        final amount = product.coinReward ?? 0;
        return 'Instantly add $amount coins to unlock upgrades and cosmetics.';
      case MonetizationProductKind.coinMultiplier:
        final multiplier = product.coinMultiplier ?? 1.0;
        final duration = product.multiplierDuration ?? const Duration();
        final days = duration.inDays;
        if (days > 0) {
          return 'Boost coin earnings for $days day${days > 1 ? 's' : ''}.';
        }
        return 'Temporarily increase the coins you earn per run.';
    }
  }
}
