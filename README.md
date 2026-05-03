# orbit

<p align="center">

[![Join Discord](https://img.shields.io/badge/Discord-Join%20Server-5865F2?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/ffmN6cUd3u) [![GitHub Issues](https://img.shields.io/badge/GitHub-Issues-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/MoONSHO7/Orbit/issues)

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-Donate-BD5FFF?style=for-the-badge&logo=buymeacoffee&logoColor=white)](https://www.buymeacoffee.com/moonsho7)

</p>

orbit is a modular ui suite for world of warcraft built directly into blizzard's native edit mode. no complex setup, no heavy overhaul — high-end extensions for the default ui, designed to feel like blizzard wrote them.

## features

| | |
|---|---|
| **edit mode native** | every orbit frame is selectable, draggable, and resizable in blizzard's own edit mode |
| **canvas mode** | a dedicated dialog for fine-tuning individual components inside a single frame |
| **cooldown manager** | talent-aware spell tracking with charge displays and per-spec layouts |
| **tracked** | user-authored cooldown / aura tracker that complements cooldown manager |
| **unit frames** | player, target, focus, and boss frames with sync-size and shared skinning |
| **group frames** | party and raid frames with aura layout and dispel highlighting |
| **action bars** | skinned native bars with full edit mode integration |
| **cast bars** | player and unit cast bars with target / boss focus |
| **class resources** | advanced power displays per class and spec |
| **status bars** | experience, reputation, and honor bars with canvas-managed text components |
| **damage meter** | multi-instance, minimal-chrome meter on top of blizzard's native damage / healing pipeline |
| **datatexts** | corner-triggered drawer with stats, performance, currency, and utility readouts |
| **minimap** | reskinned minimap with clean compartment flyout and canvas-mode component placement |
| **menu items** | bag bar and micro-menu reskins |
| **spotlight** | hotkey-driven universal search across bags, gear, mounts, pets, toys, macros, and more |
| **pixel-perfect** | auto-detected ui scale and snap-to-physical-pixel rendering at any resolution |
| **smart profiles** | account-shared layouts with per-character spec data where it matters |

## modular plugin system

each component is a plugin that can be disabled. if you only want the cooldown manager, you can turn everything else off and orbit becomes a single tool. plugins live in `Orbit/Plugins/` and are independently toggled in the settings panel.

## for developers

if you'd like to contribute — bug fixes, plugins, translations, anything — start with **[CONTRIBUTE.md](CONTRIBUTE.md)**. it walks through the architecture, the three rendering systems (live frames / edit mode / canvas mode), the data-flow rules, and the conventions every pr is expected to follow.

## support

if orbit has improved your gameplay and you'd like to support continued development, the buy me a coffee link above is genuinely appreciated — but the most valuable contribution is feedback in discord and reproducible bug reports on github.

