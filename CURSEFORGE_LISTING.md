# CurseForge Listing Copy
This file is NOT part of the addon. It contains the text to paste into CurseForge fields.

---

## Project Name
Patron Order Tracker

## Summary (short blurb for search results)
One-click tracking of all fulfillable Patron Orders with automatic Auctionator shopping list creation. Only the reagents you need to supply are listed. Requires Auctionator for shopping list functionality.

## Primary Category
Professions

## Additional Category
Auction & Economy

## License
MIT License

## Description (for the project page, markdown format)

### What It Does

Tired of clicking through Patron Orders one by one to figure out what you need to buy?

**Patron Order Tracker** adds a single button to the Patron Orders tab. One click and it:

- Scans every loaded Patron Order for your current profession
- Skips recipes you haven't learned
- Tracks each fulfillable recipe in your objective tracker
- Calculates exactly which reagents **you** must supply (subtracting what the NPC customer already provides)
- Creates an **Auctionator shopping list** with only your share of the materials

Head to the Auction House, open Auctionator's Shopping tab, find your **"PatronOrderTracker - [Profession]"** list, and buy everything you need in one search.

### How To Use

1. Open Professions > Crafting Orders > **Patron Orders** tab
2. Wait for orders to load
3. Click **"Track All Fulfillable Orders"**
4. Go to the Auction House > Auctionator > Shopping tab
5. Select your **"PatronOrderTracker - [Profession]"** list and search
6. Click **"Clear Patron Tracking"** when you're done

### Auctionator Required

Shopping list creation requires [Auctionator](https://www.curseforge.com/wow/addons/auctionator). Without Auctionator installed, recipes are still tracked in the objective tracker but no shopping list is generated.

### Slash Commands

- `/pot dump` — Opens a diagnostic window showing every loaded patron order with a full reagent breakdown (item names, quantities needed, what the customer provides, what you must supply). The text is selectable and copyable.
- `/pot debug` — Toggles verbose debug logging to chat.

### Reagent Handling

The addon only adds **Basic** (mandatory) reagents to the shopping list. Optional reagents like Finishing and Modifying reagents are excluded — those are the crafter's choice, not order requirements.

For each order, the addon compares the full recipe schematic against the customer-provided reagents and calculates the exact delta. If the customer provides 20 out of 20 Crushed Gemstones, that reagent won't appear in your shopping list. If they provide 0 out of 4 Ostentatious Onyx, you'll see "Ostentatious Onyx [x4]" in the list.

Multiple orders for the same recipe aggregate correctly — if three orders each need 4 Ostentatious Onyx, you'll see [x12].

### Compatibility

Works alongside these popular addons without conflicts:
- **CraftSim**
- **Profession Shopping List**
- **No Mats; No Make**
- **Patron Offers**

### Feedback & Source

Found a bug or have a suggestion? Visit the [GitHub repository](https://github.com/YOUR_USERNAME/PatronOrderTracker).

---

## Changelog (for first file upload, plain text)

### 1.0.0

- Initial release
- One-click "Track All Fulfillable Orders" button on the Patron Orders tab
- Automatic reagent delta calculation (subtracts customer-provided reagents)
- Auctionator shopping list creation with only player-supplied reagents
- "Clear Patron Tracking" button to untrack recipes and remove shopping list
- /pot dump diagnostic dialog with full per-order reagent breakdown
- /pot debug toggle for development logging
