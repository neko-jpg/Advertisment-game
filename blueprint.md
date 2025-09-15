# Project Blueprint: Quick Draw Dash

## 1. Overview & MVP Goal

-   **Genre:** 1-tap/swipe drawing-based endless runner.
-   **Platform:** Flutter (iOS & Android).
-   **Session Length:** 60-120 seconds.
-   **Monetization:** Rewarded ads (primary) and interstitial ads (secondary).
-   **MVP Goal:** Achieve D1 Retention ≥ 35%, ARPDAU ≥ $0.05, and an ad view rate ≥ 30%.

---

## 2. Roadmap to Full Version

This document outlines the phased development plan to build a feature-complete version of the game.

-   **Phase 1: Coin System (Completed)**
    -   [x] Implement collectible coins within the game world.
    -   [x] Display the collected coin count on the UI.
    -   [x] Create logic for coin-player collision.

-   **Phase 2: Sound & Music (Completed)**
    -   [x] Integrate the `audioplayers` package.
    -   [x] Add background music (BGM).
    -   [x] Add sound effects (SFX) for jumping, collecting coins, and game over.

-   **Phase 3: Interstitial Ads (Completed)**
    -   [x] Integrate interstitial ads to be shown periodically on game over.

-   **Phase 4: Firebase Analytics (In Progress)**
    -   Integrate `firebase_analytics`.
    -   Log key events like `game_start`, `game_end`, `coins_collected`, `ad_watched`.

-   **Phase 5: Visual Enhancements**
    -   Replace the player circle with an animated sprite.
    -   Improve the visual design of the background and obstacles.

---

## 3. Current Implementation Details

-   **Coin System:** Players can collect coins that appear on the screen. The total is displayed in the UI.
-   **Endless Runner Core:** The player can jump and must avoid obstacles scrolling from the right.
-   **Drawing Mechanic:** The player can draw platforms to run on (1.5s lifetime, 1.2s cooldown).
-   **Game Over & Restart:** Collision with an obstacle triggers a "Game Over" state.
-   **Rewarded Ad for Revive:** A "Watch Ad to Revive" button appears on the game over screen.
-   **Interstitial Ads:** Shown every 3rd game over.
-   **Difficulty Curve:** Game speed increases with the score.
-   **Sound & Music:** BGM and SFX are implemented.

---

## 4. Monetization Strategy

-   **Rewarded Ads (Primary):**
    -   **Revive:** **(Implemented)** Continue from the point of failure.
    -   **Bonus:** Double the coins collected after a run. *(Phase 1 Dependent)*
-   **Interstitial Ads (Secondary):**
    -   **Implemented:** Shown only after a game session ends, with rate-limiting.

---

## 5. Technical Architecture

-   **State Management:** `provider` (`ChangeNotifier`, `ChangeNotifierProxyProvider`).
-   **Game Loop:** A `Ticker` for consistent updates.
-   **Rendering:** `CustomPaint` for all game elements.
-   **Ad Integration:** `google_mobile_ads` SDK.
-   **Sound:** `audioplayers` for BGM and SFX.
-   **Backend:** Firebase for Analytics and Remote Config. *(Phase 4)*

