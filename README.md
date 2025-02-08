## Golden-Pro-Sim

I decided to try and see if I could send shots to Golden Tee Classic using shot data from my launch monitor (Approach R10). You can read more about the journey to figure out at the [Open Golf Sim](https://opengolfsim.com/) website.


## Getting Started

- Download a release from the releases page.
- Open `settings.json` in your favorite text editor
    - Edit the value of `mame` to point to where you installed `mame.exe`
    - Edit the value of `rom` to point to where you downloaded `gtclassc.zip`

    > For legal reasons, you'll need to figure out how to obtain the Golden Tee Classic `gtclassc` ROM on your own.

### Memory Addresses

To actually read game data, we have to inspect thousands of lines of active memory blocks while the game plays, and determine which blocks get set to specific values

| Address | Notes |
| --- | --- |
| `0x001960` | Yardage        |
| `0x002480` | Club Selection |
| `0x0025E0` | Seems to get set to all `0x00`s during gameplay |
| `0x001A00` | Seems to change between scenes, but no good pattern found |
| `0x802480` | Random backdoor text like GAME COINS CLEARED |
