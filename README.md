# LuaUnicode3
Unicode Services for Lua

Project is still seriously in-progress; this readme will keep track of my list of what still needs to be implemented.

TODO:
* Provide thorough documentation and manual in several formats
* Ability to get/update library via LuaRocks
* Continue to add thorough testing scripts
* Implement UString:ToTitlecase()
* Implement most of the original string methods from the Lua standard library
* Finish implementing addition of all remaining character properties to the Master Table
* Update Unicode support from 7.0 to the most recent version of Unicode
* Update all PowerShell scripts to function correctly with `pwsh` on *nix systems
* Implement all remaining standard Unicode algorithms:
** Text Segmentation
** Line Breaking
** Bidirectional
* Implement some form of pattern matching or regular expression
** Ideally, provide either pre-made patterns that can be used with LPeg or provide our own re-creation of LPeg for UStrings, or both.
* Implement file I/O library