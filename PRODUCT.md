# Wayday product context

<!-- impeccable:product-schema 1 -->

## Platform

android

## Stack

Flutter/Dart with Riverpod and GoRouter, as selected in [the stack inventory](docs/wayday/STACK.md). iOS is a later target.

## Product authority

[Product scope](docs/wayday/PRODUCT.md) and [decisions](docs/wayday/DECISIONS.md) remain the maintained product authorities. This entry point makes their location discoverable to design tools; it does not replace them.

## Current implementation scope

The owner authorized the Android app shell and Today module, then refined the scope to include Recurring on 2026-10-16. Preserve V2's From/Errands/To structure and compact numbered list. Start with example errands. Use one light Cornflower theme without appearance controls. Quick add defaults to Anytime; focused screens hold details. Recurring contains reusable lists added manually to Today, with independent copies and descriptive repeat metadata. Place selection opens a clearly labeled map placeholder; time selection uses numeric hour/minute entry. Data remains in memory. Real routing, business search, persistence, notifications, backend work, and iOS remain later work.

## Evidence on hand

The latest refinement adds optional multiline notes, independent note copies, smooth list insertion/disclosure, and themed transient in-app feedback. Preserve consecutive-entry focus and honor reduced motion. Android reminder notifications remain separate, deferred work.

The [V2 notes](docs/Asikaso-Prototype/V2-NOTES.md), [historical design system](docs/Asikaso-Prototype/DESIGN.md), and [V2 screenshots](docs/Asikaso-Prototype/docs/screenshots/v2) provide provisional interaction references. The supplied image is visual inspiration only. Preserve historical source material.

## Brand commitments

Use Wayday. Keep the interface clean, refined, and uncluttered. The owner supplied Canvas `#FBFBF8`, Mist `#DBE3E9`, Cornflower `#6AA6DA`, and black as references. The initial palette options have been superseded by a single light Cornflower direction. The five-digit black value is interpreted as `#000000`.
