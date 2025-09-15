# Blueprint: Quick Draw Dash MVP

## Overview

This document outlines the design, features, and development plan for the "Quick Draw Dash" mobile game MVP. The project is a hyper-casual, ad-supported game built with Flutter, targeting both iOS and Android platforms.

## Style, Design, and Features

### Core Concept
- **Game:** A 2D endless runner where the player draws lines on the screen to navigate and avoid obstacles.
- **Objective:** Achieve the highest score possible by surviving as long as you can.
- **Target Audience:** Casual gamers, commuting users (ages 15-35).

### Visual Design
- **Aesthetics:** Colorful and vibrant visuals with a clean, minimalist UI.
- **Effects:** Glowing effects for the drawn lines and satisfying particle effects for feedback (e.g., collecting items, near misses).
- **Layout:** Simple and intuitive, with a focus on the gameplay area.

### Core Mechanics
- **Drawing Control:** Players swipe on the screen to draw lines that act as platforms or ramps for the player character.
- **Endless Progression:** The game's speed and difficulty will gradually increase over time.
- **Scoring:** The score will be based on the distance traveled.

### Monetization
- **Primary Model:** In-app advertising using Google AdMob.
- **Ad Types:**
    - **Rewarded Video Ads:** Allow players to continue after a failure or receive in-game boosts.
    - **Interstitial Ads:** Displayed between game sessions (e.g., every 3-5 minutes).

## Current Development Plan

The current goal is to build the foundational structure of the application.

### Phase 1: Project Setup & Core Game Structure

1.  **Initialize Project:**
    *   Add `google_mobile_ads` dependency for ad integration.
    *   Configure Firebase for backend services if needed.
2.  **Create Blueprint:**
    *   Establish `blueprint.md` to track project goals and progress.
3.  **Develop Main Game Screen:**
    *   Remove the default Flutter counter application.
    *   Implement a basic game screen layout with a placeholder for the game canvas.
    *   Initialize the Google Mobile Ads SDK within the app.
4.  **Implement Drawing Canvas:**
    *   Create a widget that captures user touch input and draws lines on the screen.
5.  **Basic Game Loop:**
    *   Create a simple player character and obstacle.
    *   Implement game logic where the player character moves forward and interacts with drawn lines and obstacles.
