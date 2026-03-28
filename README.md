# Patron Order Tracker

![Patron Order Tracker](logo.png)

One-click Auctionator shopping list creation for all fulfillable Patron Orders.

## What It Does

A single button on the Patron Orders tab that scans every loaded order for your current profession, skips recipes you haven't learned, calculates exactly which reagents you must supply (subtracting what the NPC customer already provides), and creates an Auctionator shopping list with only your share of the materials.

## How To Use

1. Open **Crafting Orders** > **Patron** at your profession's crafting table
2. Wait for orders to load
3. Click **"Create Auctionator Shopping List"**
4. Go to the Auction House > Auctionator > **Shopping** tab
5. Select your **"PatronOrderTracker - [Profession]"** list and search
6. Click **"Clear Auctionator Shopping List"** when you're done

## Auctionator Integration

Shopping list creation requires [Auctionator](https://www.curseforge.com/wow/addons/auctionator). Without Auctionator installed, no shopping list is created.

## Slash Commands

- `/pot dump` - Opens a copyable diagnostic window showing every loaded patron order, reagent breakdown, and what the addon would add to the shopping list
- `/pot debug` - Toggles debug logging to chat

## Install

Copy the `PatronOrderTracker` folder into your `Interface/AddOns/` directory, or install via CurseForge.