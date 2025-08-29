
### `README.md`

```markdown
# MyCombatTextCoachSmart_Dungeon

**Version:** 1.0  
**Author:** uxhazeanalyst  
**License:** Non-commercial personal use only (see LICENSE.txt)

---

## Overview

MyCombatTextCoachSmart_Dungeon is a World of Warcraft addon designed to enhance your combat experience by:

- Displaying multi-school combat text in real time.  
- Tracking physical, magical, blocked, absorbed, parried, dodged, and missed damage.  
- Providing smart coaching advice for your class/spec defensive cooldowns.  
- Offering post-combat and full dungeon summaries.  
- Tracking Mythic+ dungeon progress with real-time mob kill indicators.

---

## Installation

1. Download or clone this repository.  
2. Place the folder in your WoW `Interface/AddOns/` directory:  

```

World of Warcraft/
└─ *retail*/
└─ Interface/
└─ AddOns/
└─ MyCombatTextCoachSmart\_Dungeon/

```

3. Launch WoW and enable the addon from the AddOns menu.

---

## License

This addon is provided **free for personal, non-commercial use**.  

You may:

- Use it while playing WoW.  
- Modify it for personal use.  

You may **not**:

- Redistribute, sell, or sublicense this addon.  
- Use it commercially or incorporate it into other products without explicit permission.  

All rights reserved. Please see `LICENSE.txt` for full details.

---

## Features

- Floating combat text with **color-coded damage types**.  
- Real-time **Mythic+ dungeon progress tracking**.  
- **Class-specific cooldown tracking** and usage suggestions.  
- Detailed **combat and dungeon summaries** with coaching advice.  
- Configurable text size and color via `options.lua`.

---

## Contact

For questions, suggestions, or bug reports, contact **YourName** or open an issue on this repository.
```
================================
# SLASH COMMANDS
================================
/mcts size <num>        → Set text size (e.g. /mcts size 20)
/mcts colors <type> <r> <g> <b> 
                       → Set custom RGB color (0-1 range)
/mcts multischool on/off → Toggle showing multi-school tags
/mcts combat on/off      → Toggle end-of-combat summaries
/mcts dungeon on/off     → Toggle end-of-dungeon summary
/mcts coach on/off       → Toggle smart coaching advice
/mcts reset              → Reset all settings to defaults
/mcts share              → Export your settings as a Base64 string
/mcts import <string>    → Import settings from a Base64 string
