import 'package:flutter/material.dart';
import '../models/content_models.dart';
import '../content_variation_engine.dart';

/// Widget for selecting and managing visual themes
class ThemeSelectionWidget extends StatefulWidget {
  const ThemeSelectionWidget({
    super.key,
    required this.engine,
    this.onThemeChanged,
  });

  final ContentVariationEngine engine;
  final VoidCallback? onThemeChanged;

  @override
  State<ThemeSelectionWidget> createState() => _ThemeSelectionWidgetState();
}

class _ThemeSelectionWidgetState extends State<ThemeSelectionWidget> {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Visual Themes',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Switch(
                  value: widget.engine.state.themePreferences.autoSwitchEnabled,
                  onChanged: (value) {
                    setState(() {
                      widget.engine.setAutoSwitchEnabled(value);
                    });
                    widget.onThemeChanged?.call();
                  },
                ),
              ],
            ),
            if (widget.engine.state.themePreferences.autoSwitchEnabled)
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Auto-switch enabled: Themes will change automatically',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            const SizedBox(height: 16),
            _buildThemeGrid(),
            const SizedBox(height: 16),
            if (widget.engine.state.themePreferences.personalizedRecommendations.isNotEmpty)
              _buildRecommendations(),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: VisualTheme.values.length,
      itemBuilder: (context, index) {
        final theme = VisualTheme.values[index];
        return _buildThemeCard(theme);
      },
    );
  }

  Widget _buildThemeCard(VisualTheme theme) {
    final isUnlocked = widget.engine.isThemeUnlocked(theme);
    final isSelected = widget.engine.state.themePreferences.selectedTheme == theme;
    final progress = widget.engine.getThemeUnlockProgress(theme);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: isUnlocked ? () => _selectTheme(theme) : null,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 3 : 1,
          ),
          gradient: isUnlocked
              ? LinearGradient(
                  colors: [
                    colorScheme.primary.withOpacity(0.3),
                    colorScheme.secondary.withOpacity(0.3),
                  ],
                )
              : null,
          color: isUnlocked ? null : Colors.grey.shade200,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: colorScheme.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    theme.displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isUnlocked ? Colors.black : Colors.grey,
                    ),
                  ),
                  Text(
                    theme.description,
                    style: TextStyle(
                      fontSize: 10,
                      color: isUnlocked ? Colors.black54 : Colors.grey,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Positioned(
                top: 4,
                right: 4,
                child: Icon(
                  Icons.check_circle,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
            if (!isUnlocked)
              Positioned(
                bottom: 4,
                left: 4,
                right: 4,
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.engine.state.totalPlays}/${theme.unlockRequirement} plays',
                      style: const TextStyle(fontSize: 8, color: Colors.grey),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendations() {
    final recommendations = widget.engine.state.themePreferences.personalizedRecommendations;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recommended for you',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: recommendations.length,
            itemBuilder: (context, index) {
              final theme = recommendations[index];
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: _buildRecommendationChip(theme),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationChip(VisualTheme theme) {
    final colorScheme = theme.colorScheme;
    
    return GestureDetector(
      onTap: () => _selectTheme(theme),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              colorScheme.primary.withOpacity(0.7),
              colorScheme.secondary.withOpacity(0.7),
            ],
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: colorScheme.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              theme.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectTheme(VisualTheme theme) {
    setState(() {
      widget.engine.selectTheme(theme);
    });
    widget.onThemeChanged?.call();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected theme: ${theme.displayName}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}