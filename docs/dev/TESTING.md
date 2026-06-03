# Iconic — Manual Testing Checklist

Run the app fresh and walk through every section. Check off each box as you go. Note any issues at the bottom.

**Setup tip:** to test onboarding/first-run, reset state first:
```bash
# Reset onboarding for all possible bundle identifiers
for domain in app.iconic.Iconic com.app.Iconic com.himank.Iconic com.iconic.app; do
  defaults write "$domain" iconic.onboardingCompleted -bool false
  defaults delete "$domain" iconic.excludePatterns.populatedDefaults 2>/dev/null
done
```
Then build & launch: `xcodebuild -project Iconic.xcodeproj -scheme Iconic -derivedDataPath /tmp/iconic-build && open /tmp/iconic-build/Build/Products/Debug/Iconic.app`

Make a throwaway test folder tree first:
```bash
mkdir -p ~/Desktop/IconicTest/{Music,Photos,Code/MyApp,Documents/Reports,Videos,Downloads,Games,Travel/Italy,node_modules,.git}
touch ~/Desktop/IconicTest/Code/MyApp/.git
```

---

## 1. First-Launch Onboarding

- [ ] App launches and **onboarding sheet appears** (not the main window directly)
- [ ] Onboarding scrolls smoothly — content doesn't get cut off
- [ ] Intro section shows before/after folder icons
- [ ] **Drag & Drop tip panel** is visible (blue, `hand.draw` icon)
- [ ] **Icon Style picker** lets you choose Emoji vs SF Symbol — selection persists
- [ ] Icon Style cards are fully clickable (entire card area, not just the folder icon)
- [ ] **Matching mode section** shows AI vs Local; AI reveals an API key input field
- [ ] Matching mode cards are fully clickable (entire card area, not just the icon/text)
- [ ] **Dry Run safety section** is visible (green, `eye` icon) — explains preview mode
- [ ] **SIP warning section** is visible (orange, `lock.shield` icon)
- [ ] "Skip for Now" button dismisses the sheet
- [ ] Quit & relaunch → onboarding does **not** show again
- [ ] Reset (run the setup tip command above) → onboarding shows again

---

## 2. Main Window — Top Control Strip

- [ ] Below the header, there's a horizontal strip with: **Icon Style picker**, **AI Matching toggle**, **Dry Run toggle**
- [ ] Icon Style picker is segmented (Emoji / SF Symbol)
- [ ] Toggling Icon Style changes what previews render (after a scan)
- [ ] AI Matching toggle reflects the same state as Preferences > Gemini AI
- [ ] Dry Run toggle reflects `vm.isDryRunMode` — flipping it shows/hides the dry-run banner
- [ ] All three controls visually match each other (compact, captioned, secondary background)

---

## 3. Choose Folder Flow

- [ ] Click **Choose Folder** (or ⌘O) → file picker opens
- [ ] Pick `~/Desktop/IconicTest` → app scans and lists subfolders
- [ ] Folder path shown in header
- [ ] Progress indicator visible during scan
- [ ] Each row shows: folder name, matched symbol/emoji preview, status badge

## 4. Drag & Drop

- [ ] Drag `~/Desktop/IconicTest` from Finder onto the app window → it scans
- [ ] Drag a **file** (not folder) onto the window → rejected gracefully (no crash)
- [ ] Drag multiple folders at once → all get scanned

---

## 5. Matching Modes

### Local mode (default if no Gemini key)
- [ ] Turn off AI toggle → re-scan
- [ ] Common names match correctly: `Music` → music note, `Photos` → camera/photo, `Videos` → film, `Code` → chevron/code, `Downloads` → arrow down
- [ ] Footer shows "Local" badge

### AI mode (needs Gemini API key)
- [ ] In Preferences > Gemini AI: paste key, click Test → success message
- [ ] Save key, enable AI toggle
- [ ] Re-scan → footer shows "AI" badge
- [ ] AI-matched items show some confidence indicator
- [ ] Disconnect network, re-scan → silently falls back to local + warning toast
- [ ] AI confidence < 0.7 → folder is left **Unassigned** (plain system folder, "Unassigned" badge, Apply disabled). Verify by scanning a folder with a generic name that the model can't confidently classify.
- [ ] AI returns a bad symbol name (e.g. garbage) → folder is Unassigned, not force-mapped to `folder.fill`

### Smart content detection
- [ ] Preferences > Detection: enable smart detection
- [ ] Re-scan → `Code/MyApp` (contains `.git`) gets a Git-themed icon
- [ ] `node_modules` if not excluded gets a Node-themed icon

---

## 6. Exclude Patterns (Preferences > Detection)

- [ ] Detection tab shows an **Excluded folder names** list
- [ ] Pre-seeded patterns visible: `.git`, `node_modules`, `DerivedData`, `.build`, `Pods`, `.next`, `.cache`, `__pycache__`, `.venv`
- [ ] Type a new pattern + click "+" → pattern added
- [ ] Trash icon on a row removes it
- [ ] Re-scan `~/Desktop/IconicTest` → `node_modules` and `.git` **do not appear** in the list
- [ ] Remove `node_modules` from excludes, re-scan → it appears again

## 7. Scan Depth Limit

- [ ] Detection tab has **Maximum scan depth** stepper (1–20)
- [ ] Set to 1 → re-scan `~/Desktop/IconicTest` → only top-level subfolders appear (no `MyApp`, no `Italy`, no `Reports`)
- [ ] Set to 10 → re-scan → nested folders appear again
- [ ] Set to 20 then 1 then 20 → stepper persists across sessions

---

## 8. Search & Filter

- [ ] Search bar filters items in real-time as you type
- [ ] Clear search → all items return
- [ ] Filter chips: All / Pending / Applied / Restored / Failed / **Unmapped**
- [ ] Click **Unmapped** → only rows that the matcher gave up on show (match source = `Unassigned`, "?" badge, plain system folder preview). These are folders that the AI couldn't confidently classify (confidence < 0.7), the local dictionary had no hit for, AND no rule / custom mapping / smart detection matched.
- [ ] Click Applied (after applying some) → only applied items show

## 9. Icon Style (Emoji vs SF Symbol)

- [ ] Top strip: switch to Emoji → all previews re-render as emoji
- [ ] Switch back to SF Symbol → all previews re-render as symbols
- [ ] Setting persists across app restarts

## 10. Auto-Color Assignment

- [ ] Preferences > Appearance: ensure "Automatically assign beautiful colors" is on
- [ ] Re-scan → icons get varied colors (not all one color)
- [ ] Music folder gets a music-palette color, Code gets a code-palette color, etc.
- [ ] Disable auto-color → re-scan → icons use the default color
- [ ] Change default color in Appearance tab → re-scan → new color applies
- [ ] **Auto-color does NOT tint Unassigned rows** — they stay the plain system folder (no folder color, no symbol color) even when auto-color is on

---

## 11. Unassigned Folders

A folder is "Unassigned" when the matcher couldn't confidently resolve a symbol for it. This is a real state now, not a hidden `folder.fill` fallback.

**Triggers (any one):**
- AI mode is on and Gemini returns confidence < **0.7** (raised from the old 0.6 threshold)
- AI mode is on and the model returns a symbol name that doesn't exist in the running macOS SF Symbols
- AI mode is on and the API call fails partway through the batch — only the unresolved folders end up Unassigned, the rest still match normally
- All matchers fail: no rule, no smart detection hit, no custom mapping, and the local dictionary / fuzzy / tag search all came back empty

**UI:**
- [ ] Row preview is the **plain system folder** (no symbol overlay, no folder tint, no symbol tint)
- [ ] Subtitle reads **"No symbol match — folder left as system default"** (instead of the usual `symbolName` label)
- [ ] Match-source badge says **"Unassigned"** with a `?` icon
- [ ] Per-row swatches are gray placeholders
- [ ] **Apply button is disabled** (both the row button and the context-menu "Apply Icon" item); tooltip explains why
- [ ] **Retry button is visible** (same affordance as failed rows)
- [ ] Pencil button tooltip reads "Pick a symbol for this folder" instead of "Edit SF Symbol for this folder"
- [ ] Pencil button opens a focused symbol editor: title is "Pick a symbol for this folder", text field and **Browse** button are at the top, suggestions below, text field is auto-focused

**Behavior:**
- [ ] **Apply All** silently skips Unassigned rows and shows a toast like "Skipping N folder(s) with no symbol match" (icon: `questionmark.circle`)
- [ ] **Auto-Watch** (Preferences > Background) for a newly-created folder with no match → folder is Unassigned, no icon is written, no auto-apply
- [ ] Picking a symbol via the pencil button (Browse / type / suggestion) transitions the row out of the Unassigned state — `matchSource` becomes `userEdited`, Apply is enabled, and the swatches become editable
- [ ] Unassigned rows survive a re-scan (they don't get a "real" match just because the scan ran again, unless the matcher now finds one)
- [ ] Resetting Preferences or clearing all mappings does not turn Unassigned into Mapped — Unassigned reflects what the matcher said about the folder name, not user preferences

**Quick repro:**
```bash
mkdir -p ~/Desktop/IconicTest/zzzqwerty_random_xyz_123
# Re-scan ~/Desktop/IconicTest — the new subfolder is Unassigned
# Verify: row shows plain system folder, Apply is disabled, Retry is visible
# Then click pencil → "Pick a symbol for this folder" → type "questionmark" → Apply
# → row transitions out of Unassigned, Apply button enables
```

## 12. Per-Folder Color Picker

Each row has **two inline color swatches** between the status badge and the pencil button — the left one shows the folder color, the right one shows the symbol color. They default to gray (no override set). Clicking either swatch (or the sliders button) opens the **Adjust** popover, which has a dedicated **Colors** section.

- [ ] Two 12×12 color swatches visible on every row (folder color on the left, symbol color on the right)
- [ ] Hover swatch → tooltip "Folder color" / "Symbol color" (or "… (default)" if the override is nil)
- [ ] Click a swatch → Adjust popover opens
- [ ] In the popover, **Colors** section has two rows: "Folder Color" and "Symbol Color", each with a native ColorPicker
- [ ] Pick a folder color → row preview updates live (folder tint changes immediately)
- [ ] Pick a symbol color → row preview updates live (symbol tint changes immediately)
- [ ] When a color is set, an ✕ button appears next to the picker; click it → override cleared, color falls back to the global default / auto-color chain
- [ ] When a color is nil, the row shows a "default" label next to the picker
- [ ] Click **Reset** at the bottom of the Adjust popover → both color overrides clear, along with the other size/opacity/gradient/custom-image adjustments
- [ ] Apply this folder → applied Finder icon uses the chosen colors
- [ ] Unassigned rows: swatches and color pickers still work — picking a symbol + color on an unassigned row transitions it out of the unassigned state (sets `matchSource` to `userEdited`) and enables Apply
- [ ] The Preferences > Appearance "Default Symbol Color" picker now matches what the in-row text promises ("override this per-folder using the color picker in the main list")

---

## 13. Dry Run / Preview Mode

- [ ] Toggle Dry Run on (top strip or footer) → banner appears
- [ ] Click "Apply All" → status changes but **Finder icons do NOT change**
- [ ] Toggle Dry Run off, Apply All → Finder icons **do** change
- [ ] Verify in Finder: `~/Desktop/IconicTest/Music` shows the new icon

---

## 14. Apply All & Conflict Review

- [ ] First-time apply (no existing icons): Apply All runs immediately
- [ ] Apply some icons; then re-scan and try Apply All again
- [ ] **Conflict modal appears** showing "N folders already have custom icons"
- [ ] Modal buttons: Apply / Review Conflicts / Cancel
- [ ] "Cancel" → nothing changes
- [ ] "Apply" → conflicts overwritten

## 15. Batch Progress Detail

- [ ] During Apply All, footer shows **"Applying X/Y — N failed"** format
- [ ] Progress count updates live
- [ ] Failed count appears only when failures occur

---

## 16. Undo / Redo

- [ ] After an Apply, footer **Undo button** (`arrow.uturn.backward`) is enabled
- [ ] Click Undo → icons revert in Finder
- [ ] **Redo button** (`arrow.uturn.forward`) is enabled after undo
- [ ] Click Redo → icons re-apply
- [ ] Buttons disabled when nothing to undo/redo
- [ ] ⌘Z and ⌘⇧Z also work
- [ ] Hover Undo → tooltip shows what action will be undone

---

## 17. Per-Row Retry Button

The retry button (`arrow.clockwise`) appears on rows that the matcher gave up on. It now covers three states:

- [ ] **Failed** rows (e.g. SIP-protected folders) — try scanning `/System`
- [ ] **Unassigned** rows (matcher had no confident answer) — try scanning a folder with a random name like `xyzqwerty123`
- [ ] **Generic-fallback** rows (matched the old `folder` / `folder.fill` symbol) — rare after recent matcher changes, but still supported
- [ ] Click retry → re-matches that single folder using the current matching mode (Local or AI)
- [ ] On Pending / Applied / Restored rows that have a real symbol, the retry button is **not** visible
- [ ] After a successful retry on an unassigned row, the row transitions out of the Unassigned state and Apply becomes enabled

## 18. Restore Defaults

- [ ] Apply some icons in Finder
- [ ] Click "Restore Defaults" in footer → icons revert to standard folder
- [ ] Per-row restore (if available) reverts single folder

---

## 19. Custom Mappings (Preferences > Mappings)

- [ ] Add a mapping: keyword `xyz` → symbol `star.fill`
- [ ] Create `~/Desktop/IconicTest/xyzTest`, re-scan → row uses `star.fill`
- [ ] Delete the mapping → re-scan → uses fallback

## 20. Rules (Preferences > Rules)

- [ ] Add a rule: pattern type (Contains/Exact/Glob/Regex), pattern, target symbol
- [ ] Re-scan → rule applies before other matchers
- [ ] Delete rule → reverts to normal matching

## 21. Templates (Preferences > Templates)

- [ ] Save current setup as a template
- [ ] Modify settings, then load the template → settings restored

## 22. Presets (Preferences > Presets)

- [ ] Save current configuration as preset
- [ ] Export preset → file saved
- [ ] Modify settings, import preset → settings restored

---

## 23. Symbol Browser

SF Symbols and emoji are two separate browsers; both are reachable from the pencil button in any row.

### 23a. SF Symbol Browser
- [ ] From a row's pencil button → **Browse Symbols…** → SF Symbol Browser sheet opens
- [ ] Footer shows "**7968 symbols**" (Apple's full catalog, not just the curated 190)
- [ ] Scroll the grid — LazyVGrid stays smooth
- [ ] Search bar matches **both** the symbol name and Apple's tags: typing `music` surfaces `headphones`, `equalizer`, `music.note`, etc. (even when "music" isn't in the symbol's name)
- [ ] Category chips: All / Communication / Weather / Objects / Nature / Symbols / Media / **Music** / **Camera** / **Home** / **Transportation** / **People** / Code / Work / Travel / Creative / Gaming / Education / Health
- [ ] Click a category → grid narrows to symbols Apple tagged with that category
- [ ] Click a symbol → it commits to the row, sheet dismisses
- [ ] Unavailable symbols (not in the running macOS version) render as a dashed `?` placeholder
- [ ] Switch to Emoji style in Preferences → pencil button now shows **Browse Emoji…** instead of **Browse Symbols…**

### 23b. Emoji Browser
- [ ] With Emoji style active, **Browse Emoji…** from the pencil button opens the Emoji Browser sheet
- [ ] Footer shows "**1907 emoji**" (Apple's full emoji set, not just the first 240)
- [ ] No-query view is sorted **alphabetically by Apple name** (e.g. ATM Sign, American Football, Aquarius, …) — not the previous source-order random slice
- [ ] Search by name: typing `music` surfaces `🎵`, `🎶`, `🎸`, etc.
- [ ] Search by tag: typing `love` surfaces `❤️`, `💕`, etc.
- [ ] Pasting an actual emoji into the search bar filters to emojis containing that grapheme cluster (handles multi-character sequences like flag emojis)
- [ ] Click an emoji → it commits to the row, sheet dismisses

## 24. Menu Bar Mode

- [ ] Preferences > Background: enable "Keep app in menu bar when window closes"
- [ ] Close window → menu bar icon appears
- [ ] Click menu bar icon → shows actions, restores window

## 25. Background Folder Monitor

- [ ] Preferences > Background: enable "Monitor folders for new subfolders"
- [ ] Add a monitored location (e.g. `~/Desktop/IconicTest`)
- [ ] In Finder, create a new folder inside it → after a moment, app detects it
- [ ] Notification toggle on → macOS notification appears when icons apply

---

## 26. Keyboard Shortcuts

- [ ] ⌘O → open folder picker
- [ ] ⌘Z / ⌘⇧Z → undo/redo
- [ ] ⌘F → focus search (verify)
- [ ] ⌘, → open Preferences
- [ ] Arrow keys navigate rows; Space toggles row (verify)
- [ ] ⌘/ → keyboard shortcuts help panel opens

## 27. Preferences Search

- [ ] Preferences window has a search field
- [ ] Type "exclude" → routes you to Detection tab
- [ ] Type "depth" → routes to Detection
- [ ] Type "color" → routes to Appearance

---

## 28. Error Handling & Edge Cases

- [ ] Scan `/System` → folders show failed status with sensible error message (SIP)
- [ ] Scan a huge folder tree (e.g. `~`) → app stays responsive, can cancel
- [ ] Cancel mid-scan → app returns to ready state
- [ ] Disconnect internet, scan with AI → falls back to local + warning toast
- [ ] Invalid Gemini key → Test button shows clear error
- [ ] Quit during apply → relaunch → state is sane (no half-applied items in weird state)

## 29. Finder Verification

After Apply All on `~/Desktop/IconicTest`:
- [ ] Open Finder, navigate to the folder
- [ ] Each subfolder shows its custom icon
- [ ] Icons crisp at all sizes (icon view, list view, column view, gallery view)
- [ ] Icons survive renaming the folder
- [ ] Icons survive moving the folder

---

## 30. Persistence Across Restart

After quitting and relaunching:
- [ ] Last-opened folder remembered (security-scoped bookmark works)
- [ ] All Preferences settings retained
- [ ] Icon Style choice retained
- [ ] AI on/off state retained
- [ ] Exclude patterns retained
- [ ] Scan depth retained
- [ ] Custom mappings / rules / templates / presets all retained

---

## 31. Cleanup

```bash
# Restore default icons on test folders
# (or use the Restore Defaults button in app)
rm -rf ~/Desktop/IconicTest
```

---

## Issues Found

Use this section to note anything broken or weird:

| # | Section | Issue | Severity |
|---|---------|-------|----------|
|   |         |       |          |
|   |         |       |          |
|   |         |       |          |
