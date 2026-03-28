# Patron Order Tracker

![Patron Order Tracker](logo.png)

One-click tracking of all fulfillable Patron Orders with Auctionator shopping list integration.

## What It Does

A single button on the Patron Orders tab that scans every loaded order for your current profession, skips recipes you haven't learned, tracks each fulfillable recipe in your objective tracker, calculates exactly which reagents you must supply (subtracting what the NPC customer already provides), and creates an Auctionator shopping list with only your share of the materials.

A second button clears all tracking and removes the shopping list when you're done.

## How To Use

1. Open Professions > Crafting Orders > **Patron Orders** tab
2. Wait for orders to load
3. Click **"Track All Fulfillable Orders"**
4. Go to the Auction House > Auctionator > **Shopping** tab
5. Select your **"PatronOrderTracker - [Profession]"** list and search
6. Click **"Clear Patron Tracking"** when you're done

## Auctionator Integration

Shopping list creation requires [Auctionator](https://www.curseforge.com/wow/addons/auctionator). Without it, recipes are still tracked in the objective tracker but no shopping list is created.

## Slash Commands

- `/pot dump` - Opens a copyable diagnostic window showing every loaded patron order, reagent breakdown, and what the addon would track
- `/pot debug` - Toggles debug logging to chat

## Install

Copy the `PatronOrderTracker` folder into your `Interface/AddOns/` directory, or install via CurseForge.