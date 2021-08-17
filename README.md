# Unicode Services for Lua
Comprehensive Unicode library for Lua

Project is still seriously in-progress; this readme will keep track of my list of what still needs to be implemented.

TODO:
* Provide thorough documentation and manual in several formats
* Implement support for reserved characters, private-use characters, and noncharacters
* Ability to get/update library via LuaRocks
* Continue to add thorough testing scripts
* Implement UString:ToTitlecase()
* Implement most of the original string methods from the Lua standard library
* Finish implementing addition of all remaining character properties to the Master Table
* Update Unicode support from 7.0 to the most recent version of Unicode
* Update all PowerShell scripts to function correctly with `pwsh` on \*nix systems
* Implement all remaining standard Unicode algorithms: (plus other minor algorithms and operations)
  * Text Segmentation
  * Line Breaking
  * Bidirectional
* Implement some form of pattern matching or regular expression
  * Create our own clone of LuLPeg which operates over UStrings
* Implement file I/O library
* Implement string and character proxies support (via loading a us4l.UseProxies module loaded before any others) to allow use in sandboxed environments