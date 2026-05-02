# Orbit

<p align="center">

[![Join Discord](https://img.shields.io/badge/Discord-Join%20Server-5865F2?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/ffmN6cUd3u) [![GitHub Issues](https://img.shields.io/badge/GitHub-Issues-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/MoONSHO7/Orbit/issues)

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-Donate-BD5FFF?style=for-the-badge&logo=buymeacoffee&logoColor=white)](https://www.buymeacoffee.com/moonsho7)

</p>

Orbit is a modular UI suite for World of Warcraft built directly into Blizzard's native Edit Mode. No complex setup, no heavy overhaul — high-end extensions for the default UI, designed to feel like Blizzard wrote them.

## Features

| | |
|---|---|
| **Edit Mode Native** | Every Orbit frame is selectable, draggable, and resizable in Blizzard's own Edit Mode |
| **Canvas Mode** | A dedicated dialog for fine-tuning individual components inside a single frame |
| **Cooldown Manager** | Talent-aware spell tracking with charge displays and per-spec layouts |
| **Tracked** | Custom cooldown / aura tracker that complements Cooldown Manager |
| **Unit Frames** | Player, Target, Focus, and Boss frames with sync-size and shared skinning |
| **Group Frames** | Party and raid frames with aura layout and dispel highlighting |
| **Action Bars** | Skinned native bars with full Edit Mode integration |
| **Cast Bars** | Player and unit cast bars with target / boss focus |
| **Class Resources** | Advanced power displays per class and spec |
| **Status Bars** | Experience, reputation, honor, and azerite-style segmented bars |
| **Damage Meter** | Skinning and integration for Blizzard's native damage meter |
| **Datatexts** | Performance, currency, and utility readouts in a customizable drawer |
| **Minimap** | Reskinned minimap with clean compartment flyout |
| **Menu Items** | Bag bar and micro-menu reskins |
| **Spotlight** | Hotkey-driven universal search across bags, gear, mounts, pets, toys, macros, and more |
| **Pixel-Perfect** | Auto-detected UI scale and snap-to-physical-pixel rendering at any resolution |
| **Smart Profiles** | Account-shared layouts with per-character spec data where it matters |

## Modular Plugin System

Each component is a plugin that can be disabled. If you only want the Cooldown Manager, you can turn everything else off and Orbit becomes a single tool. Plugins live in `Orbit/Plugins/` and are independently toggled in the settings panel.

## For developers

If you'd like to contribute — bug fixes, plugins, translations, anything — start with **[CONTRIBUTE.md](CONTRIBUTE.md)**. It walks through the architecture, the three rendering systems (live frames / Edit Mode / Canvas Mode), the data-flow rules, and the conventions every PR is expected to follow.

## Support

If Orbit has improved your gameplay and you'd like to support continued development, the Buy Me A Coffee link above is genuinely appreciated — but the most valuable contribution is feedback in Discord and reproducible bug reports on GitHub.
