# Internal Notes (not for public readers)

The `.md` files in this directory are **internal development session notes**
and AI-coordination context that were used while building Iconic. They are
preserved here for two reasons:

1. **Continuity for AI-assisted development.** Files like `AGENTS.md` and
   `CLAUDE.md` give future AI coding sessions the project context they
   need to be productive.
2. **Historical record of the design journey.** Files like
   `AI_IMPROVEMENTS.md`, `AI_CURRENT_STATUS.md`, and `FEATURES.md` capture
   design decisions and trade-offs that don't belong in the public README.

## What's in here

| File | Purpose |
|---|---|
| `AGENTS.md` | Project tour for AI coding agents. Largely superseded by `../architecture.md`; kept for the AI-specific framing. |
| `CLAUDE.md` | Anthropic-Claude-specific companion to `AGENTS.md`. |
| `AI_*.md` | Snapshots of the AI design / status / implementation summary at various points during development. |
| `CONTENT_ANALYSIS_SUMMARY.md` | Research notes for the optional AI content-analysis feature. |
| `FEATURES.md` | Long-form feature catalog. Superseded by the README's "Why Iconic" section. |
| `ICONS_AND_COLORS_GUIDE.md` | Design rationale for the symbol and color systems. |
| `MENU_BAR_GUIDE.md` | Internal notes on the menu-bar mode. |
| `PROJECT_COMPLETE.md` | Pre-release milestone summary. |
| `QUICKREF.md` | Developer quick-reference (conventions, file map, build commands). |
| `TESTING.md` | Pre-release testing notes. |

## Public counterparts

External contributors should read:

- [`../architecture.md`](../architecture.md) — data flow, layer
  responsibilities, where to add a keyword/palette/detector.
- [`../THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md) — attributions
  for derived data.
- [`../../CONTRIBUTING.md`](../../CONTRIBUTING.md) — how to contribute.

If you are an external contributor and you found a doc you think should be
public, open an issue and we'll review it.
