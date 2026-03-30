# Patron Order Tracker

![Patron Order Tracker](logo.png)

One-click Auctionator shopping list creation for all fulfillable Patron Orders.

## What It Does

A single button on the Patron Orders tab that scans every loaded order for your current profession, skips recipes you haven't learned, calculates exactly which reagents you need to supply (subtracting what the NPC customer already provides), and creates an Auctionator shopping list with only your share of the materials.

## Features

- **One-click shopping list** from all fulfillable Patron Orders
- **Order budget** to automatically skip orders that cost more than you want to spend
- **Inline cost preview** on each order row, using Auctionator's price data

## How To Use

1. Open **Crafting Orders** > **Patron** at your profession's crafting table
2. Wait for orders to load. You'll see estimated material costs on each order
3. (Optional) Click the **gear button** to set an order budget — orders over this cost will be skipped
4. Click **"Create Auctionator Shopping List"**
5. Open the Auction House and open the **Shopping** tab in Auctionator
6. Select your shopping list: **"POT - LW (Bigcatross-Area52)"**
7. Click **"Clear Auctionator Shopping List"** when you're done

## Requirements

Requires [Auctionator](https://www.curseforge.com/wow/addons/auctionator).

## Slash Commands

- `/pot dump` - Copyable diagnostic window with full order and reagent breakdown
- `/pot debug` - Toggle debug logging to chat

## Install

Install via [CurseForge](https://www.curseforge.com/wow/addons/patron-order-tracker), or copy the `PatronOrderTracker` folder into your `Interface/AddOns/` directory.
