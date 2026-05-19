# DeepTutor Mobile — 2026 Premium UI/UX Redesign

## Executive summary

DeepTutor Mobile is repositioned from a template-style dashboard into a **futuristic AI learning operating system**: cinematic depth, glass surfaces, bento modularity, floating dock navigation, and emotionally rewarding gamification—aligned with Arc, Linear, Raycast, Perplexity, Duolingo Max, Notion AI, and VisionOS.

---

## 1. Design strategy

### North star
> *"A billion-dollar AI learning platform designed in 2026."*

### Principles
| Principle | Implementation |
|-----------|----------------|
| **AI-native** | Hero orb, live status, contextual copy, pulse accents on Chat |
| **Cinematic depth** | Mesh gradients, particle field, layered glow (not flat cards) |
| **Hierarchy** | Hero → XP → tools → bento → missions (single scroll narrative) |
| **Performance** | Blur only on hero/XP/dock; bento uses gradients + shadows |
| **Emotion** | Streak flame animation, XP radial ring, mission rarity colors |

### Inspiration mapping
| Reference | What we borrow |
|---------|----------------|
| **Arc / Raycast** | Floating dock, glass chrome, command-ready density |
| **Linear** | Typography rhythm, muted labels, sharp section headers |
| **Perplexity** | AI presence, live indicators, clean answer surfaces |
| **Duolingo Max** | Streak flame, XP momentum, mission feed rewards |
| **VisionOS** | Glass, depth, floating navigation, soft glow |
| **Notion AI** | Calm intelligence, adaptive copy, workspace grouping |

---

## 2. Color system (`app_colors.dart`) — Copper AI OS

| Token | Value | Role |
|-------|-------|------|
| `copperPrimary` | `#D4734B` | Primary accent, CTAs, nav, pulses |
| `surfaceGlass` | `#FFFFFF0D` | Translucent containers (~5% white) |
| `voidBlack` | `#000000` | Ultra-deep matte base |
| `copperLight` / `copperDeep` | Gradients, glow depth |

- **Dark:** void black mesh + copper ambient orbs
- **Light:** warm `#F7F5F2` base, `#0D000000` glass
- **Module accents:** copper-tinted cohesive palette via `AppFeatureColors`

---

## 3. Typography

- **Dark mode:** Space Grotesk (geometric, futuristic headlines)
- **Light mode:** Plus Jakarta Sans (premium SaaS readability)
- **Hero:** `headlineSmall` w800, negative letter-spacing
- **Section labels:** uppercase micro-labels with 1.4 tracking (`Intelligence feed`)

---

## 4. Dashboard architecture (implemented)

### Section 1 — AI Hero (`AiHeroSection`)
- Animated gradient orb + sweep ring
- `AI ONLINE` live pill
- Contextual greeting + motivational insight by time-of-day
- Glass surface + violet glow

### Section 2 — XP Module (`PremiumXpModule`)
- Radial level ring (circular percent indicator)
- Animated linear XP bar + animated counter
- Pulsing streak flame
- Milestone strip: next level, rank, badge count

### Section 3 — Bento grid (`BentoDashboard`)
- **Asymmetric layout:** large AI Chat (pulse bars), stacked Practice/Books, mission row, code/knowledge/learn row
- `BentoFeatureCard`: gradient fill, edge glow, press scale, optional live pulse

### Section 4 — Intelligence feed
- Premium mission cards with rarity gradient (XP threshold)
- Section header with micro-label + title

### Quick tools
- Horizontal chips: Progress, Roadmap, TutorBots, Whiteboard, Co-Writer, Space

---

## 5. Navigation (`FloatingDockNav`)

- **Phone:** VisionOS-style floating glass dock (blur + gradient border + selection glow)
- **Tablet:** Extended `NavigationRail` (unchanged pattern, upgraded theme)
- `DockShellPadding` reserves bottom inset so content is not obscured
- `extendBody: true` for content to breathe under dock

---

## 6. Motion design spec

| Token | Value | Use |
|-------|-------|-----|
| `AppAnimations.standard` | 280ms | Dock selection, containers |
| `AppAnimations.staggerStep` | 45ms | List entrance |
| Press scale | 0.94 → 1.0 | Bento cards |
| Orb pulse | 2400ms | Hero |
| Streak flame | 900ms | XP module |
| Mesh drift | 12s | Background |

**Rules:** prefer `Curves.easeOutCubic` / `easeOutBack`; avoid linear motion on UI chrome.

---

## 7. Flutter implementation architecture

```
lib/
  core/
    theme/           app_colors, app_theme, app_animations, app_spacing
    widgets/
      design_system/ glass_surface, ambient_mesh_background
  features/
    home/
      widgets/       ai_hero_section, premium_xp_module, bento_*, missions_preview
      screens/       home_screen
    shell/
      widgets/       floating_dock_nav
      app_shell.dart
```

### Widget hierarchy (home)
```
AmbientMeshBackground
  └─ CustomScrollView
       ├─ AiHeroSection (GlassSurface)
       ├─ PremiumXpModule (GlassSurface)
       ├─ QuickToolsRow
       ├─ BentoDashboard
       └─ MissionsPreview (premium cards)
```

### Performance
- Limit `BackdropFilter` to hero, XP, dock (3 surfaces max per screen)
- Bento: `BoxDecoration` gradients only (GPU-friendly)
- `AnimatedBuilder` / `TweenAnimationBuilder` over heavy `setState` trees
- Particle count capped at 24

### Recommended packages (future)
| Package | Purpose |
|---------|---------|
| `flutter_animate` | Declarative stagger (optional) |
| `rive` | Lottie-level mascot / level-up |
| `sensors_plus` | Subtle parallax on hero (optional) |

---

## 8. Responsive strategy

- **Phone:** single column bento, dock bottom
- **Tablet (≥600dp):** rail + full-width bento (consider 2-column bento in phase 2)
- **Wide (≥840dp):** constrain content `maxContentWidth: 720` centered

---

## 9. Phase 2 roadmap

- [ ] Learn hub bento + glass refactor
- [ ] Chat thread: liquid composer, neural stage timeline
- [ ] Profile: achievement holographic grid
- [ ] FAB command palette (Raycast-style)
- [ ] Rive level-up fullscreen
- [ ] Reduce motion accessibility flag wired to `AppAnimations`
- [ ] Light mode mesh tuning

---

## 10. Perceived quality checklist

- [x] No uniform square grid on home
- [x] Floating dock vs generic `NavigationBar`
- [x] AI presence in hero (orb + live pill)
- [x] Gamification feels alive (radial XP + flame)
- [x] Depth via mesh + glass + glow
- [x] Premium typography (Space Grotesk dark)
- [ ] Full-app consistency (roll out to Learn, Chat, Profile)

---

*Implemented in `deeptutor_mobile` — run `flutter run -d chrome` with dark theme for the full effect.*
