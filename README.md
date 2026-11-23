# RPQuest

[![Build](https://github.com/JerbilX/RPQuests/actions/workflows/ci.yml/badge.svg)](https://github.com/JerbilX/RPQuests/actions/workflows/ci.yml)
![Version](https://img.shields.io/badge/version-1.6.0-blue)
![ESO API](https://img.shields.io/badge/ESO%20API-101051-orange)
![Dependencies](https://img.shields.io/badge/dependencies-none-brightgreen)
![Languages](https://img.shields.io/badge/i18n-EN%20%7C%20ES-informational)
[![License: GPL v3](https://img.shields.io/badge/license-GPLv3-blue)](LICENSE)

**English** | [Español](README.es.md)

A native, **zero-dependency** add-on for **The Elder Scrolls Online** (`APIVersion: 101051`) that lets you create, play, complete, and share **custom Roleplay quests** directly inside ESO's native UI.

---

## Key Features

- **Native Quest Journal Integration (`J`):** Adds a dedicated **RPQuest** tab inside the standard Quest Journal (`ZO_QuestJournal_Keyboard`) with exclusive accordion sections for **Pending** offers, active **Quests**, **Completed** missions, **Preparing** (unsent drafts), and **Sent** (dispatched contracts with live status and completion results).
- **Reticle NPC Target Capture:** Aim at any living NPC and press your **Capture Target under Reticle** keybind to register objectives automatically. Capturing the same NPC name multiple times stacks into `Imp x3`; different named NPCs are tracked individually, with optional per-target location conditions (`Required` / `Not Required`), an `Optional` objective toggle (enabling manual quest completion once mandatory objectives are done), and custom elimination messages.
- **Hidden Discovery Points:** Capture in-world exploration coordinates via your **Capture Discovery Point** keybind with configurable trigger radii (`Small`, `Medium`, `Large`) without cluttering the map or compass with spoilers.
- **Optional Stealth / Undetected Condition:** Require players to complete objectives without being detected in combat.
- **World Map Search Area (`M`):** Displays an approximate search circle (`ZO_PinBlob`) on the World Map using a deterministic, fixed random offset—keeping the target inside the circle without revealing its exact center. Automatically clears upon completion or deactivation.
- **Native NPC Dialogue Injection:** Bind custom RPQuest dialogue lines and per-NPC player response options to native ESO NPCs (via reticle capture or NPC name), injected seamlessly into the native interaction window without altering original NPC options.
- **Combat & Discovery Tracking + Native Alerts:** Tracks kills (`EVENT_COMBAT_EVENT`) and exploration proximity, triggering native `CENTER_SCREEN_ANNOUNCE` banners and official quest sounds (`SOUNDS.QUEST_COMPLETED`).
- **HUD Mini-Tracker:** Displays the active custom quest on the side of your screen (left-click opens the Journal; right-click centers the World Map on the search area).
- **1-to-1 In-Game Mail Flow (Zero Copy/Paste):**
  - Assign a single `@AccountName` recipient (and optional `To (Character)` name) directly in the quest editor and send the quest with one click (automatically splitting larger quests up to 6 parts / ~4,000 chars via `RPQP` over `ShareCodec` internal serialization; works within the same megaserver, e.g. PC-NA to PC-NA or PC-EU to PC-EU). Both `From:` and `To:` character names are displayed below `Status:` in the quest details.
  - **Auto-Ingested Pending Quests:** Incoming quest mails are automatically ingested into the player's **Pending** list with a visible alert and **Accept** / **Reject** actions directly in the RPQuest Journal.
  - **Automatic Acceptance, Completion & Rejection Reports:** Accepting, completing, or rejecting a received quest automatically sends an `RPQC1` result mail back to the Quest Master, updating the prepared quest's live status (`Draft` / `Sent` / `Accepted` / `Completed` / `Rejected`).
- **Account-Wide Persistence & Auto-Localization:** Stores quests and progress account-wide via `ZO_SavedVars:NewAccountWide` (matching ESO's account-wide mail, with automatic non-destructive migration from legacy per-character data) and auto-detects client language (`en` / `es`).

---

## Installation

1. Download the latest release archive (or clone this repository).
2. Extract the `RPQuest` folder into your ESO AddOns directory:
   - **Windows:** `Documents\Elder Scrolls Online\live\AddOns\RPQuest\`
   - **macOS:** `~/Documents/Elder Scrolls Online/live/AddOns/RPQuest/`
   - **Linux (Steam/Proton):** `<SteamLibrary>/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/Documents/Elder Scrolls Online/live/AddOns/RPQuest/`
3. Verify that `RPQuest.txt` is located directly inside `AddOns/RPQuest/RPQuest.txt`.
4. Launch ESO and enable **RPQuest** in the **Add-Ons** menu. No external libraries are required.

---

## Quick Start

1. **Create a Quest (Quest Master):**
   - Open the Quest Journal (`J`) and switch to the **RPQuest** tab (or press your **Toggle Custom Quests Tab** keybind).
   - Click **Create Quest**, use the collapsible form sections to set **Title**, **Description / Lore**, **Search Area** size (`Small`, `Medium`, `Large`), optional **Do not be detected**, and optional **NPC Dialogue** lines.
   - In the world, aim at NPCs and press your **Capture Target** keybind, or stand at a location and press **Capture Discovery Point**.
2. **Send to a Player (1-to-1 Mail):**
   - Set the target `@AccountName` (and optional character name) in the quest editor and click **Send Quest** from the prepared quest details.
   - The player receives an alert and sees the quest under **Pending** in their **RPQuest** tab to **Accept** or **Reject**.
   - **Same-language requirement:** Quests should be played on a game client using the same language as the creator so NPC names and dialogue targets match.
3. **Play & Auto-Report:**
   - Accepting the quest activates the HUD mini-tracker, World Map search area, and any injected NPC dialogues immediately.
   - Accepting, completing, or rejecting the quest automatically mails the result back to the Quest Master, moving the contract into the **Sent** section with live status (`Sent`, `Accepted`, `Rejected`, `Completed`) and completion results (such as `Undetected` vs `Detected` and optional objective outcomes).

---

## How to Use / Guide

### 1. Roles: Quest Master vs. Player
- **Quest Master (Creator):** Authors custom quests in **Preparing**, captures NPC targets or discovery spots in the world, configures optional rules or dialogues, and dispatches contracts via in-game mail. Once sent, the Quest Master tracks live status and final outcomes in **Sent**.
- **Player (Recipient):** Receives quest offers in **Pending**, reviews the briefing, and chooses **Accept** or **Reject**. Active quests are tracked automatically in-world, and results are mailed back to the Quest Master with zero manual copy/paste.

### 2. Journal Sections (Exclusive Accordion)
The **RPQuest** tab inside the Quest Journal (`J`) uses an exclusive accordion—expanding one section collapses the others:
- **Pending:** Incoming quest offers waiting for you to **Accept** or **Reject**.
- **Quests:** Your currently accepted and active quests. Select a quest to view objectives, toggle tracking, or manually complete it once all mandatory objectives are done.
- **Completed:** Archive of finished quests you have played, including final stealth and optional objective outcomes.
- **Preparing:** Unsent quest drafts you are creating or editing as a Quest Master.
- **Sent:** Contracts you have already mailed to players, showing live status (`Sent`, `Accepted`, `Rejected`, `Completed`) and automatic completion results (such as `Undetected` vs `Detected` and optional objectives).

### 3. Quest Building Blocks
- **Targets (NPC Elimination):** Aim at any living NPC and press your **Capture Target under Reticle** keybind. Capturing the same NPC name multiple times stacks into a count (e.g. `Imp x3`); different named NPCs become separate objectives. For each target, you can toggle a **Location** condition (`Required` in the captured zone/subzone or `Not Required`), add a custom elimination message, or mark the objective as **Optional** (allowing the player to finish the quest once all mandatory objectives are complete).
- **Hidden Discovery Points:** Stand at an exploration spot and press your **Capture Discovery Point** keybind. You can configure the trigger radius (`Small`, `Medium`, or `Large`). Discovery points remain hidden on the map and compass to avoid spoilers.
- **Stealth (`Undetected`):** Enable **Undetected (Optional)** in the quest editor to challenge the player to complete the quest without being detected in combat. The quest tracks whether the player remained `Undetected` or was `Detected` and reports that outcome to the Quest Master.
- **World Map Search Area (`M`):** Displays an approximate search circle on the World Map using a fixed random offset so the objective stays inside the circle without giving away its exact center. The circle clears automatically when the quest is completed or deactivated.
- **NPC Dialogues:** Open dialogue (`E`) with up to 3 native ESO NPCs to capture them into the quest's **NPC Dialogues** section, then write a custom player response option and NPC reply for each. When the player speaks to those NPCs, your custom line is injected seamlessly into the native dialogue window without modifying original game options.

### 4. In-Game Mail Flow (Automatic)
- **Sending:** Enter the recipient's `@AccountName` (and optional character name) in the quest editor and click **Send Quest**. Both players must be on the same megaserver (e.g. PC-NA or PC-EU) and use the same client language. Larger quests are split automatically across up to 6 mail parts (`RPQP`) and reassembled on arrival.
- **Arrival Announcement:** When a quest mail arrives, RPQuest ingests it automatically and displays an on-screen announcement alerting the player that a new quest is waiting in **Pending**.
- **Accepting & Rejecting:** Clicking **Accept** activates the quest, HUD mini-tracker, World Map search area, and NPC dialogues, and notifies the Quest Master. Clicking **Reject** declines the offer and notifies the Quest Master.
- **Completion Reporting:** When the player finishes all objectives (or manually completes a quest with only optional objectives remaining), RPQuest automatically mails the completion report (`RPQC1`) back to the Quest Master and updates the contract in **Sent**.

---

## Controls (`Settings -> Controls -> RPQuest`)

| Action | Description |
| :--- | :--- |
| **Capture Target under Reticle** | Captures the living NPC currently under your reticle into the quest draft. |
| **Capture Discovery Point** | Captures your current character position as a hidden discovery objective. |
| **Toggle Custom Quests Tab** | Opens or closes the Quest Journal directly on the **RPQuest** tab. |

---

## Requirements & Compatibility

- **Game Version:** The Elder Scrolls Online (`APIVersion: 101051`)
- **External Libraries:** None (`Zero-Dependency`)
- **SavedVariables:** `RPQuest_SavedVariables` (account-wide)
- **Supported Languages:** English (`en`), Spanish (`es`)

---

## Project Structure & Development

```text
RPQuest/
├── RPQuest.txt              # Official ESO add-on manifest
├── RPQuest.lua              # Entry point & EVENT_ADD_ON_LOADED lifecycle
├── Bindings.xml             # Native keybind definitions
├── lang/
│   ├── en.lua               # English strings (Base / Fallback)
│   └── es.lua               # Spanish strings
├── src/
│   ├── Constants.lua        # Constants, radii, and metadata
│   ├── Locale.lua           # Client language selector & i18n
│   ├── BinaryCodec.lua      # Base85, Base64Url, LZSS, and Varint binary primitives
│   ├── ShareCodec.lua       # RPQ3 & RPQC1 quest/result serialization
│   ├── MailInbox.lua        # Inbox scanning, RPQP multipart reassembly & ingestion
│   ├── MailTransport.lua    # In-game quest & completion mail transport
│   ├── QuestDraftStore.lua  # Draft authoring state & objective normalization
│   ├── QuestMigration.lua   # Non-destructive character SavedVars migration to account-wide
│   ├── QuestRepository.lua  # Account-wide CRUD, quest import/export & runtime tracking
│   ├── Announcements.lua    # CENTER_SCREEN_ANNOUNCE & sound alerts
│   ├── TargetCapture.lua    # Reticle NPC & discovery point capture
│   ├── CombatTracker.lua    # Kill & stealth tracking (EVENT_COMBAT_EVENT)
│   ├── DiscoveryTracker.lua # Hidden discovery proximity polling
│   ├── DialogueInjector.lua # Native NPC dialogue injection
│   ├── WorldMapArea.lua     # Native search circle on ZO_WorldMap
│   ├── JournalWidgets.lua   # Reusable UI widget & formatting helpers for JournalTab
│   ├── JournalDetailPane.lua# Quest detail pane & action button builders/refresh
│   ├── JournalEditorSections.lua# Accordion section & field builders for quest editor
│   ├── JournalEditorPane.lua# Multi-section quest editor pane layout/refresh
│   ├── JournalMailSendPane.lua# In-game mail send pane & transport event UI
│   └── JournalTab.lua       # Native Quest Journal tab coordinator
├── docs/adr/                # Architecture Decision Records (MADR)
└── tests/
    ├── run.lua              # Hermetic unit test suite (LuaJIT)
    └── mocks/               # EsoUI mocks
```

### Running Tests
```bash
luajit tests/run.lua
```

---

## AI Disclosure & Credits

- **Author:** [JerbilX](https://github.com/JerbilX)
- **AI Assistance Disclosure:** AI coding assistants were used during development to assist with Lua code drafting, refactoring, localization, documentation, and unit test scaffolding. All feature design, architecture decisions, in-game testing, and final code reviews were directed and verified by the author.

---

## License

This project is licensed under the **GNU General Public License v3.0** — see [LICENSE](LICENSE) for details.
