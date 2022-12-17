# Mpv-nextfile
This script will force open next or previous file in the currently playing files directory. 

#### Settings
Set them inside the settings variable at the head of the lua file. Should work out of the box.
- filtering by filetype
- Allow/disallow looping
- linux/windows
 
#### keybindings
You can copy paste below into your input.conf if you want to change the keybindings.  
  `shift+LEFT script-binding previousfile`  
  `shift+RIGHT script-binding nextfile` 
 
 
#### My other mpv scripts
- [collection of scripts](https://github.com/jonniek/mpv-scripts)

---

## Fork info

Original author: [jonniek](https://github.com/jonniek)  
Forked from: [mpv-nextfile](https://github.com/jonniek/mpv-nextfile)

#### Changes
- Added back load next file automatically feature
- Disable autoload when the played file is in a playlist and not the last one
- Restore old keybindings: use `PgUp` and `PgDn` instead of arrows 
