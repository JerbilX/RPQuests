# Roadmap Reference Benchmarks: Total RP 3 & Total RP 3: Extended

> **Tracking Issue:** [#226](https://github.com/JerbilX/RPQuests/issues/226)
> **Scope:** Long-term product, UX, and feature-design North Star for RPQuest. Concrete features inspired by these benchmarks should be broken down into dedicated implementation issues.

---

## 1. Benchmark Addons

- **Total RP 3:** https://www.curseforge.com/wow/addons/total-rp-3
- **Total RP 3: Extended:** https://www.curseforge.com/wow/addons/total-rp-3-extended

These addons serve as reference benchmarks for roleplay tooling, authoring ergonomics, and interactive storytelling—adapted to *The Elder Scrolls Online* (ESO) public API and EsoUI constraints.

---

## 2. Reference Areas to Evaluate & Adapt

| Area | Benchmark Capabilities to Study | ESO / EsoUI Adaptation Focus |
| :--- | :--- | :--- |
| **Quest & Campaign Authoring** | Multi-step quest structure, conditional branching (`if`/`else`), triggers, and reusable templates/duplication. | Map authoring concepts onto RPQuest's SavedVariables schema and step/objective model while keeping editor forms lightweight. |
| **Interactive Storytelling & Dialogues** | Conditional NPC dialogues, clue/discovery progression, and narrative feedback. | Align dialogue trees, state flags, and discovery cues with ESO's native interaction feel and RPQuest's objective progression. |
| **Co-op & Sharing Flows** | Smooth player-to-player quest sharing, party/partner synchronization, and completion reporting. | Design sharing and sync flows around ESO's sanctioned communication and payload-size constraints without blocking solo play. |
| **UI/UX Polish** | Clean authoring workflows, intuitive editors, and immersive in-game presentation. | Maintain visual consistency with ESO's native UI, responsive layouts, and keybind-first access (`Settings -> Controls -> RPQuest`). |

---

## 3. Adaptation Principles

1. **ESO-Native First:** Translate UX patterns to EsoUI idioms rather than porting WoW-specific UI conventions verbatim.
2. **API & Compliance Boundaries:** All inspired features must adhere strictly to ESO's public API, SavedVariables limits, and EsoUI / Baertram compliance rules.
3. **Incremental Delivery:** Use this document as an evaluation baseline; break each concrete capability into scoped child issues with clear acceptance criteria and ADRs when architectural changes are needed.
