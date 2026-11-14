# Cyber System Monitor (Omarchy Shell Plugin)

An electric cyberpunk-themed system resource monitor and telemetry HUD for the [Omarchy](https://omarchy.org/) Linux shell.

![Cyber System Monitor](preview.png)

## Features

- ⚡ **Futuristic Cyber Bar Pill**: Glanceable, real-time CPU & RAM usage percentages with glowing neon cyan and violet accents.
- 📊 **Detailed Telemetry Popout**: Click to expand a complete system telemetry card:
  - Live CPU percentage bar, CPU temperature, and load average.
  - Memory (RAM) used / total in GB with interactive visual progress bar.
  - Swap utilization monitoring.
  - Top 3 CPU-intensive processes table with individual CPU & RAM metrics.
  - Live uptime counter with animated online status badge.
- 🚀 **Interactive Quick Actions**:
  - **Left Click**: Open/close the telemetry popup HUD.
  - **Right Click**: Instantly launch or focus `btop` in a floating terminal.
  - **Middle Click**: Trigger an immediate metrics refresh.
- 🌍 **Internationalization (i18n)**: Fully compatible with Omarchy's 50+ live translation languages via JSON locale catalogs.
- 🛡️ **UI Safety & Native Motion**: Strictly adheres to Omarchy's `Text.PlainText` safety guidelines and smooth native shell easing curves.

---

## Installation

Install directly via the Omarchy CLI:

```bash
omarchy plugin add https://github.com/Adicodes270/cyber-sysmon.git --enable
```

Or clone it locally and enable it manually:

```bash
# Link or place in your user plugins directory
ln -s ~/Documents/omarchy-plugins/cyber-sysmon ~/.config/omarchy/plugins/aditya27003.cyber-sysmon

# Rescan and enable on the right section of the bar
omarchy plugin enable aditya27003.cyber-sysmon --section right
```

---

## Customization

You can move or rearrange the widget placement at any time:

```bash
# Move to another bar section (left, centerBegin, centerEnd, right, tray)
omarchy bar move aditya27003.cyber-sysmon --section right
```

Edits saved to `BarWidget.qml` or `manifest.json` will hot-reload live on your desktop without needing a shell restart.

---

## Author

- **Aditya Kumar** ([@Adicodes270](https://github.com/Adicodes270))

## License

MIT License. See [LICENSE](LICENSE) for details.
