# PatronOrderTracker

World of Warcraft addon that creates Auctionator shopping lists from Patron Orders.

## Project Structure

- `PatronOrderTracker.toc` — addon metadata, interface version, dependencies
- `PatronOrderTracker.lua` — all addon code (single file)
- `logo.tga` — in-game addon icon (256x256 TGA, WoW-compatible)
- `logo.png` — branding for GitHub/CurseForge (not shipped in CF package)
- `.pkgmeta` — CurseForge packager config (ignore list, manual changelog)
- `CHANGELOG.md` — curated changelog used by CurseForge via `.pkgmeta` manual-changelog directive

## Release Workflow

1. Make changes and copy to WoW folder for testing:
   ```
   cp PatronOrderTracker.toc PatronOrderTracker.lua "/g/Battle.net Games/World of Warcraft/_retail_/Interface/AddOns/PatronOrderTracker/"
   ```
2. Test in-game with `/reload`
3. **Wait for user confirmation before committing**
4. Bump version in `PatronOrderTracker.toc` and add entry to `CHANGELOG.md`
5. Commit, push, tag, create GitHub release
6. CurseForge picks up the tag automatically via webhook

Never push, tag, or release untested changes. Copy to the WoW folder and stop — wait for testing.

## WoW Addon Conventions

- Target current retail patch only — no backwards compatibility
- Use official WoW terminology: "reagents" not "mats", "fulfillable" not "craftable"
- No global namespace pollution — use `local` variables, anonymous frames where possible
- No frames created in hot paths — lazy-create once, reuse
- `hooksecurefunc` and `HookScript` for hooks — never `SetScript` on existing Blizzard frames
- `pcall` only for calling APIs we don't control (Auctionator internals) — let our own code fail loudly
- Auctionator is an OptionalDep — always guard with `if Auctionator and Auctionator.API` checks

## Key APIs

- `C_CraftingOrders.GetCrafterOrders()` — flat order list (has per-order reagent data)
- `C_CraftingOrders.GetCrafterBuckets()` — bucketed view (no per-order reagent data)
- `C_TradeSkillUI.GetRecipeSchematic(spellID, isRecraft)` — recipe reagent slots
- `C_TradeSkillUI.GetRecipeInfo(spellID)` — check `.learned` status
- `Auctionator.API.v1.CreateShoppingList(callerID, name, searchStrings)` — creates/replaces a shopping list
- `Auctionator.API.v1.ConvertToSearchString(callerID, term)` — encodes a SearchTerm table
- `Auctionator.Shopping.ListManager:GetIndexForName(name)` — check if a list exists (internal API, used for clear button)
- `Auctionator.Shopping.ListManager:Delete(name)` — delete a list (internal API, no public alternative)
- `ContinuableContainer` — batch async item name resolution (same pattern Auctionator uses)

## Verified Blizzard Source Locations

- Frame hierarchy: `Blizzard_ProfessionsCrafterOrderPage.xml` and `.lua` in Gethe/wow-ui-source
- Data structures: `CraftingOrderUISharedDocumentation.lua`
- Enums: `ProfessionConstantsDocumentation.lua`
- Auctionator API: read directly from `G:\Battle.net Games\World of Warcraft\_retail_\Interface\AddOns\Auctionator\Source\API\v1\ShoppingLists.lua`

## Known Decisions

- `order.isFulfillable` is NOT used for gating — it returns false for orders the player can clearly craft. We check `recipeInfo.learned` instead.
- Only Basic (mandatory) reagents are included in the shopping list. Modifying/Finishing/Automatic are optional and excluded.
- No bag inventory subtraction — matches Auctionator's own convention for tracked recipe searches.
- No recipe tracking (SetRecipeTracked) — removed in v1.0.1, the addon focuses purely on the Auctionator shopping list.
- No SavedVariables — clear button checks Auctionator's live state directly via ListManager:GetIndexForName.

## Publishing

- GitHub: https://github.com/codecrete-ross/PatronOrderTracker
- CurseForge: auto-packaged via webhook on tag push
- License: All Rights Reserved
- `.pkgmeta` excludes: `.github`, `.gitignore`, `README.md`, `.pkgmeta`, `logo.png`
- `.pkgmeta` includes `CHANGELOG.md` via manual-changelog directive for CF changelog display

## Slash Commands

- `/pot dump` — copyable diagnostic dialog with per-order reagent breakdown
- `/pot debug` — toggle verbose debug logging to chat
