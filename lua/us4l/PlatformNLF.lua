--Currently no way implemented to detect classic MacOS or an EBCDIC-based system

local ret = "\10" --LF

--Note that package.config does exist in 5.1, it's merely undocumented
if package.config and package.config:sub(1,1) == "\\" then --Windows
    ret = "\13\10" --CR LF
end

return ret