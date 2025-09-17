import 'package:flutter/material.dart';
import '../drawing_tool_system.dart';
import '../models/content_models.dart';

/// Widget for displaying and managing the artwork gallery
class ArtworkGalleryWidget extends StatefulWidget {
  const ArtworkGalleryWidget({
    super.key,
    required this.drawingSystem,
    this.onArtworkSelected,
  });

  final DrawingToolSystem drawingSystem;
  final Function(PlayerArtwork)? onArtworkSelected;

  @override
  State<ArtworkGalleryWidget> createState() => _ArtworkGalleryWidgetState();
}

class _ArtworkGalleryWidgetState extends State<ArtworkGalleryWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          _buildHeader(),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Recent', icon: Icon(Icons.access_time)),
              Tab(text: 'Featured', icon: Icon(Icons.star)),
              Tab(text: 'Stats', icon: Icon(Icons.analytics)),
            ],
          ),
          SizedBox(
            height: 400,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRecentTab(),
                _buildFeaturedTab(),
                _buildStatsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final stats = widget.drawingSystem.getArtworkStats();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade100, Colors.blue.shade100],
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.palette, size: 32, color: Colors.purple),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Artwork Gallery',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${stats['totalArtworks']} artworks • ${stats['totalLikes']} likes',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          _buildSelectedToolIndicator(),
        ],
      ),
    );
  }

  Widget _buildSelectedToolIndicator() {
    final selectedTool = widget.drawingSystem.selectedTool;
    final effect = widget.drawingSystem.getDrawingEffect(selectedTool);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: effect.colors.first.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: effect.colors.first),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: effect.colors.first,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            selectedTool.displayName,
            style: TextStyle(
              color: effect.colors.first,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTab() {
    final recentArtworks = widget.drawingSystem.getRecentArtworks();
    
    if (recentArtworks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.brush_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No artworks yet', style: TextStyle(color: Colors.grey)),
            Text('Create your first masterpiece!', 
                 style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: recentArtworks.length,
      itemBuilder: (context, index) {
        final artwork = recentArtworks[index];
        return _buildArtworkCard(artwork);
      },
    );
  }

  Widget _buildFeaturedTab() {
    final featuredArtworks = widget.drawingSystem.getFeaturedArtworks();
    
    if (featuredArtworks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No featured artworks', style: TextStyle(color: Colors.grey)),
            Text('Create high-scoring artworks to see them here!', 
                 style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: featuredArtworks.length,
      itemBuilder: (context, index) {
        final artwork = featuredArtworks[index];
        return _buildFeaturedArtworkCard(artwork, index + 1);
      },
    );
  }

  Widget _buildStatsTab() {
    final stats = widget.drawingSystem.getArtworkStats();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatCard(
            'Total Artworks',
            '${stats['totalArtworks']}',
            Icons.palette,
            Colors.purple,
          ),
          _buildStatCard(
            'Shared Artworks',
            '${stats['sharedArtworks']}',
            Icons.share,
            Colors.blue,
          ),
          _buildStatCard(
            'Total Likes',
            '${stats['totalLikes']}',
            Icons.favorite,
            Colors.red,
          ),
          _buildStatCard(
            'Average Score',
            '${(stats['averageScore'] as double).toStringAsFixed(1)}',
            Icons.score,
            Colors.green,
          ),
          _buildStatCard(
            'Drawing Time',
            _formatDuration(Duration(milliseconds: stats['totalDrawingTime'] as int)),
            Icons.timer,
            Colors.orange,
          ),
          _buildStatCard(
            'Total Strokes',
            '${stats['totalStrokes']}',
            Icons.brush,
            Colors.teal,
          ),
          const SizedBox(height: 16),
          _buildToolUsageChart(stats['toolUsage'] as Map<String, int>),
        ],
      ),
    );
  }

  Widget _buildArtworkCard(PlayerArtwork artwork) {
    return GestureDetector(
      onTap: () => widget.onArtworkSelected?.call(artwork),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.drawingSystem.getDrawingEffect(artwork.toolUsed).colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Icons.brush,
                        size: 32,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    if (artwork.isShared)
                      const Positioned(
                        top: 8,
                        right: 8,
                        child: Icon(
                          Icons.share,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artwork.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.score, size: 12, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        '${artwork.score}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const Spacer(),
                      if (artwork.likes > 0) ...[
                        Icon(Icons.favorite, size: 12, color: Colors.red.shade400),
                        const SizedBox(width: 2),
                        Text(
                          '${artwork.likes}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedArtworkCard(PlayerArtwork artwork, int rank) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRankColor(rank),
          child: Text(
            '#$rank',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(artwork.title),
        subtitle: Text(
          '${artwork.toolUsed.displayName} • Score: ${artwork.score}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (artwork.isShared) ...[
              const Icon(Icons.share, size: 16, color: Colors.blue),
              const SizedBox(width: 8),
            ],
            if (artwork.likes > 0) ...[
              Icon(Icons.favorite, size: 16, color: Colors.red.shade400),
              const SizedBox(width: 4),
              Text('${artwork.likes}'),
            ],
          ],
        ),
        onTap: () => widget.onArtworkSelected?.call(artwork),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildToolUsageChart(Map<String, int> toolUsage) {
    if (toolUsage.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = toolUsage.values.fold<int>(0, (sum, count) => sum + count);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tool Usage',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...toolUsage.entries.map((entry) {
              final tool = DrawingTool.values.firstWhere(
                (t) => t.name == entry.key,
                orElse: () => DrawingTool.basic,
              );
              final percentage = (entry.value / total * 100).round();
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: widget.drawingSystem.getDrawingEffect(tool).colors.first,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(tool.displayName),
                    ),
                    Text('$percentage%'),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber; // Gold
      case 2:
        return Colors.grey; // Silver
      case 3:
        return Colors.brown; // Bronze
      default:
        return Colors.blue;
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}