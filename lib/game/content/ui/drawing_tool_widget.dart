import 'package:flutter/material.dart';
import '../models/content_models.dart';
import '../content_variation_engine.dart';

/// Widget for selecting and managing drawing tools
class DrawingToolWidget extends StatefulWidget {
  const DrawingToolWidget({
    super.key,
    required this.engine,
    this.onToolChanged,
  });

  final ContentVariationEngine engine;
  final VoidCallback? onToolChanged;

  @override
  State<DrawingToolWidget> createState() => _DrawingToolWidgetState();
}

class _DrawingToolWidgetState extends State<DrawingToolWidget> {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Drawing Tools',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _buildToolGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildToolGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: DrawingTool.values.length,
      itemBuilder: (context, index) {
        final tool = DrawingTool.values[index];
        return _buildToolCard(tool);
      },
    );
  }

  Widget _buildToolCard(DrawingTool tool) {
    final isUnlocked = widget.engine.isDrawingToolUnlocked(tool);
    final isSelected = widget.engine.state.drawingToolPreferences.selectedTool == tool;
    final progress = widget.engine.getToolUnlockProgress(tool);

    return GestureDetector(
      onTap: isUnlocked ? () => _selectTool(tool) : null,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 3 : 1,
          ),
          color: isUnlocked ? Colors.white : Colors.grey.shade200,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildToolIcon(tool, isUnlocked),
                  const SizedBox(height: 4),
                  Text(
                    tool.displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      color: isUnlocked ? Colors.black : Colors.grey,
                    ),
                    textAlign: TextAlign.center,
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
                  size: 16,
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
                        _getToolColor(tool),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Skill ${widget.engine.state.currentSkillLevel}/${tool.skillRequirement}',
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

  Widget _buildToolIcon(DrawingTool tool, bool isUnlocked) {
    final color = isUnlocked ? _getToolColor(tool) : Colors.grey;
    final size = 32.0;

    switch (tool) {
      case DrawingTool.basic:
        return Icon(Icons.edit, color: color, size: size);
      case DrawingTool.rainbow:
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple],
          ).createShader(bounds),
          child: Icon(Icons.brush, color: Colors.white, size: size),
        );
      case DrawingTool.glowing:
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: isUnlocked ? [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ] : null,
          ),
          child: Icon(Icons.auto_fix_high, color: color, size: size),
        );
      case DrawingTool.sparkle:
        return Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.star, color: color, size: size),
            Icon(Icons.star_outline, color: Colors.white, size: size * 0.6),
          ],
        );
      case DrawingTool.fire:
        return Icon(Icons.local_fire_department, color: color, size: size);
      case DrawingTool.ice:
        return Icon(Icons.ac_unit, color: color, size: size);
    }
  }

  Color _getToolColor(DrawingTool tool) {
    switch (tool) {
      case DrawingTool.basic:
        return Colors.black;
      case DrawingTool.rainbow:
        return Colors.purple;
      case DrawingTool.glowing:
        return Colors.yellow;
      case DrawingTool.sparkle:
        return Colors.pink;
      case DrawingTool.fire:
        return Colors.red;
      case DrawingTool.ice:
        return Colors.cyan;
    }
  }

  void _selectTool(DrawingTool tool) {
    setState(() {
      widget.engine.selectDrawingTool(tool);
    });
    widget.onToolChanged?.call();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected tool: ${tool.displayName}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}