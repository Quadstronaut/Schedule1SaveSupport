# Schedule 1 Save Support (S1SS)
![Schedule 1 Save Support](Assets/s1ss.png)
## A Save Management Tool for Schedule 1

### Features

* **Save Listing:** Display all saves with Organisation Name, Game Version, Last Played Date, Elapsed Days, Cash Balance, and Bank Balance.
* **Save Vault:** Back up active saves to an unlimited vault and restore any vaulted save back to a game slot (1-5).
* **Delete:** Remove individual saves from active slots, the vault, or any unexpected folders found in the saves directory.
* **Cleanup:** Remove all unexpected (manually placed) folders found in the game's Saves directory.
* **Platform:** PowerShell 5.1+, Windows 10+. Requires running as Administrator.

> Tested on Windows 10 OS Build 19045.5796 with PowerShell 5.1.19041.5794.

### Getting Started

1. Download `saveSupport.ps1`.
2. Right-click the script and choose **Run with PowerShell** — or open an elevated PowerShell window, navigate to the script, and run `.\saveSupport.ps1`. Administrator rights are required for file operations to succeed.
3. The interactive menu lists available actions based on what saves exist.

### Usage

Run `saveSupport.ps1`. The script presents a menu of available actions each loop:

| Key | Action | When shown |
|-----|--------|------------|
| B   | Backup — copy an active save to the vault | Active saves present |
| C   | Cleanup — permanently delete all unexpected saves | Unexpected saves present |
| D   | Delete — permanently delete one save (active, unexpected, or vaulted) | Any saves present |
| R   | Restore — copy a vaulted save to a game slot (1-5) | Vaulted saves present |
| S   | Show — display all save details in a table | Always |
| Q   | Quit | Always |

Vault entries use randomly generated folder names (GUIDs) and are stored inside the S1SS vault directory.

### File Paths

| Path | Purpose |
|------|---------|
| `%USERPROFILE%\AppData\LocalLow\TVGS\Schedule I\Saves\<SteamID>\SaveGame_1` through `SaveGame_5` | Game's active save slots (read and written by S1SS) |
| `%USERPROFILE%\AppData\LocalLow\S1SS\Vault\` | S1SS vault storage for backed-up saves |

The script reads `Game.json`, `Metadata.json`, `Time.json`, `Players\Player_0\Inventory.json`, and `Money.json` from each save folder to populate the display table. If multiple Steam account directories exist, the first one found is used.

### Save Data Shown

| Field | Source file | JSON field |
|-------|-------------|------------|
| Organisation Name | `Game.json` | `OrganisationName` |
| Game Version | `Game.json` | `GameVersion` |
| Last Played Date | `Metadata.json` | `LastPlayedDate` |
| Elapsed Days | `Time.json` | `ElapsedDays` |
| Cash Balance | `Players\Player_0\Inventory.json` | `CashBalance` (first `CashData` item) |
| Bank Balance | `Money.json` | `OnlineBalance` |

### Contributing

1. Fork the repo.
2. Create a feature branch.
3. Submit a PR.

### Issues

Report bugs or suggest features via [GitHub Issues](https://github.com/Quadstronaut/Schedule1SaveSupport/issues).

### License

[CC0-1.0](LICENSE)

### Questions

Find me in my personal server: [@CMDR Duvrazh (iamnotkage) on Mission Control](https://discord.gg/sjVmCufX3f)

### Warning - Safety First

Don't run scripts from the internet without checking what they do first! The source is all right here.

---

> For the full reference — installation details, troubleshooting, and a complete save-format breakdown — see the [GitHub Wiki](https://github.com/Quadstronaut/Schedule1SaveSupport/wiki).
