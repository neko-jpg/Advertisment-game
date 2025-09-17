# Social Features System

This directory contains the complete social features implementation for Quick Draw Dash, designed to boost user engagement, retention, and viral growth.

## Overview

The social system implements three main components:
1. **Leaderboards & Competition** - Global rankings, badges, and competitive elements
2. **Friend Invitations & Sharing** - Viral growth through friend invitations and social sharing
3. **Community & Collaboration** - Team battles, monthly events, and artwork gallery

## Architecture

```
social/
├── models/
│   └── social_models.dart          # All data models for social features
├── services/
│   ├── leaderboard_service.dart    # Leaderboard data management
│   ├── friend_invitation_service.dart # Friend invitations and challenges
│   └── community_service.dart      # Teams, events, and artwork
├── ui/
│   ├── leaderboard_widget.dart     # Leaderboard UI
│   ├── social_features_widget.dart # Friend invitations and challenges UI
│   └── community_widget.dart       # Teams, events, and gallery UI
├── leaderboard_manager.dart        # Leaderboard system coordinator
├── social_sharing_manager.dart     # Social features coordinator
├── community_manager.dart          # Community features coordinator
├── social_system.dart              # Main system integration
└── README.md                       # This file
```

## Features Implemented

### 1. Leaderboard & Competition System (Requirements 4.1, 4.4)

**Global Leaderboards:**
- Global rankings with top 100 players
- Weekly and monthly leaderboards with automatic resets
- Friends-only leaderboards
- Real-time rank updates

**Badge System:**
- Achievement badges for various accomplishments
- Rarity levels (1-5 stars)
- Automatic badge awarding based on performance
- Badge types: Top Player, Weekly Champion, Monthly Champion, etc.

**Rewards:**
- Tiered rewards based on ranking (coins, special items)
- Automatic reward distribution
- Rank-based incentives

### 2. Friend Invitation & Social Sharing (Requirements 4.2, 4.3)

**Friend Invitations:**
- Send invitations via email/username
- 500 coins + limited skin reward for both parties
- Invitation tracking and management
- Friends list management

**Challenge System:**
- Send challenges to friends
- Multiple challenge types: Beat Score, Speed Run, Perfect Run, Coin Collection
- Challenge status tracking (pending, accepted, completed, failed)
- Challenge completion verification

**Social Sharing:**
- High score sharing with customizable content
- Achievement sharing with badge details
- Challenge sharing to invite friends
- Multi-platform sharing support (Twitter, Facebook, etc.)

### 3. Community & Collaboration (Requirements 4.5, 4.6)

**Team Battle System:**
- Create and join teams (max 5 members)
- Team scoring and leaderboards
- Team member management
- Leadership transfer when leader leaves

**Monthly Events:**
- Recurring community events
- Event types: Team Battles, Art Contests, Speed Challenges, Collectathons
- Event rewards and rankings
- Automatic event scheduling

**Artwork Gallery:**
- Submit player-created artwork
- Like and comment system
- Featured artwork section
- Popular artwork rankings
- Community interaction tracking

## Usage

### Initialization

```dart
// Initialize the complete social system
await SocialSystem.initialize();
```

### Post-Game Integration

```dart
// Handle score submission with full social integration
final result = await SocialSystem.instance.handlePostGameScore(
  playerId: 'player_123',
  playerName: 'PlayerName',
  score: 15000,
);

// Check for sharing opportunities
if (result.shouldPromptShare) {
  // Show sharing prompts to user
  for (final prompt in result.sharePrompts) {
    showSharePrompt(prompt);
  }
}
```

### Social Status

```dart
// Get comprehensive social status
final status = await SocialSystem.instance.getPlayerSocialStatus('player_123');

// Check for notifications
if (status.hasNotifications) {
  showNotificationBadge(status.totalNotifications);
}
```

### UI Integration

```dart
// Show leaderboards
Navigator.push(context, MaterialPageRoute(
  builder: (context) => LeaderboardWidget(
    currentPlayerId: 'player_123',
  ),
));

// Show social features
Navigator.push(context, MaterialPageRoute(
  builder: (context) => SocialFeaturesWidget(
    currentPlayerId: 'player_123',
    currentPlayerName: 'PlayerName',
  ),
));

// Show community features
Navigator.push(context, MaterialPageRoute(
  builder: (context) => CommunityWidget(
    currentPlayerId: 'player_123',
    currentPlayerName: 'PlayerName',
  ),
));
```

## Data Models

### Core Models
- `LeaderboardEntry` - Individual leaderboard entry
- `Leaderboard` - Complete leaderboard with entries
- `Badge` - Achievement badge
- `FriendInvitation` - Friend invitation data
- `FriendChallenge` - Challenge between friends
- `Team` - Team for collaborative gameplay
- `MonthlyEvent` - Community event
- `Artwork` - Player-created artwork
- `CommunityInteraction` - Likes, comments, etc.

### Manager Results
- `ScoreSubmissionResult` - Result of score submission
- `InvitationResult` - Result of invitation operations
- `ChallengeResult` - Result of challenge operations
- `TeamResult` - Result of team operations
- `ArtworkResult` - Result of artwork operations

## Requirements Compliance

✅ **Requirement 4.1**: Global leaderboard implementation with friend rankings
✅ **Requirement 4.2**: Friend invitation system with 500 coins + limited skin rewards
✅ **Requirement 4.3**: Challenge sending and receiving system
✅ **Requirement 4.4**: Badge system for ranking achievements
✅ **Requirement 4.5**: Team battle mode and monthly events
✅ **Requirement 4.6**: Artwork gallery and community features

## Testing

Comprehensive tests are provided in:
- `test/social/leaderboard_system_test.dart` - Leaderboard system tests
- `test/social/social_system_integration_test.dart` - Full integration tests

Run tests with:
```bash
flutter test test/social/
```

## Performance Considerations

- **Local Storage**: Uses SharedPreferences for offline functionality
- **Data Limits**: Maintains top 100 leaderboard entries, last 1000 interactions
- **Automatic Cleanup**: Periodic cleanup of old data
- **Efficient Updates**: Stream-based updates for real-time UI updates

## Future Enhancements

- **Real-time Multiplayer**: WebSocket integration for live competitions
- **Push Notifications**: Notify users of challenges, events, and achievements
- **Advanced Analytics**: Detailed social engagement metrics
- **Content Moderation**: Automated and manual content review for artwork
- **Seasonal Events**: Special themed events and rewards
- **Cross-Platform Sync**: Cloud synchronization across devices

## Integration Notes

The social system is designed to integrate seamlessly with:
- Game engine for score submission
- Monetization system for reward distribution
- Analytics system for engagement tracking
- Content system for themed events and artwork

All managers provide stream-based updates for reactive UI components and can be easily extended for additional social features.