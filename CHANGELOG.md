## 1.1.0

- **Order budget**: Set a max material spend per order. Orders that cost more are automatically excluded from the shopping list. Prices are pulled from Auctionator.
- **Settings dialog**: Gear button next to "Create" opens a config popup to set your order budget
- **Inline cost preview**: Each order in the Patron Orders list now shows its estimated material cost. Color-coded green/red when an order budget is set.
- **Per-character shopping lists**: Lists now include your character name (e.g. "POT - JC (Name-Realm)") so they don't collide across alts
- **Shortened list names**: Profession abbreviations (JC, BS, LW, etc.) keep Auctionator's shopping list panel clean
- Improved dialog styling to match WoW's native UI
- Cleaner, more consistent chat output messaging

## 1.0.8

- Added support for multiple Interface versions (120005, 120001, 120000) to cover live, launch, and PTR

## 1.0.7

- Fixed incorrect Interface version (120005 → 120001) that caused the addon to show as "Incompatible"

## 1.0.6

- Updated Interface version to 120005 (Patch 12.0.5) — **incorrect, reverted in 1.0.7**

## 1.0.5

- CurseForge changelog now uses curated CHANGELOG.md instead of raw git log

## 1.0.4

- Reduced CurseForge package size by excluding logo.png (only logo.tga is needed in-game)

## 1.0.3

- Fixed clear button appearing on login/reload when no shopping list exists

## 1.0.2

- Fixed stale verbiage across documentation and in-game dump output

## 1.0.1

- Removed recipe tracking (objective tracker) — the addon now focuses entirely on Auctionator shopping list creation
- Simplified "Clear" button to only delete the shopping list
- Cleaned up chat output messaging

## 1.0.0

- Initial release
- One-click "Create Auctionator Shopping List" button on the Patron Orders tab
- Automatic reagent delta calculation (subtracts customer-provided reagents)
- Auctionator shopping list creation with only player-supplied reagents
- "Clear Auctionator Shopping List" button to remove the shopping list
- `/pot dump` diagnostic dialog with full per-order reagent breakdown
- `/pot debug` toggle for development logging
