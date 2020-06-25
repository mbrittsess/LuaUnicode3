--Implements normalization of various kinds of names. Algorithms are mostly direct translations from the C#/PowerShell versions.
local export = {}

local function IsValidName ( str )
    return (#str > 0) and (not not str:find( "^[%w_%s%-]+$" ))
end

local function NormalizeCharacterName_Basic ( str )
    --[[For uniformity, flank the string with underscores, then replace any sequence of whitespace and underscores with a single
    underscore, then lowercase the string.]]
    local S1 = ( "_" .. str .. "_" )
        :gsub( "[%s_]+", "_" )
        :lower()
    
    --[[Protect non-medial hyphens, remove medial hyphens, protect spaces adjacent to non-medial hyphens, remove spaces,
    then unprotect any hyphens or spaces.]]
    local S2 = S1
        :gsub( "o%-e", "o#e" )
        :gsub( "(%w)%-(%w)", "%1%2" )
        :gsub( "_%-", "%%#" )
        :gsub( "[#%-]_", "#%%" )
        :gsub( "_", "" )
        :gsub( "#", "-" )
        :gsub( "%%", "_" )
    
    --If string doesn't match "hanguljungseongo-e", then remove any remaining medial hyphens.
    if S2 ~= "hanguljungseongo-e" then
        S2 = S2:gsub( "([^_])%-", "%1" )
    end
    
    return S2
end

local function NormalizeCharacterName_Advanced ( str )
    --[[Recursively remove all instances of "letter", "character", and "digit" until nothing gets shortened,
    then check for "CANCEL CHARACTER"]]
    local S2 = NormalizeCharacterName_Basic( str )
    
    local S3 = S2
    local S3i = S3
    repeat
        S3i = S3;
        S3 = S3i:gsub( "letter", "" ):gsub( "character", "" ):gsub( "digit", "" )
    until #S3i == #S3
    
    if S3 == "cancel" then
        S3 = S2
        repeat
            S3i = S3
            S3 = S3i:gsub( "letter", "" ):gsub( "digit", "" )
        until #S3i == #s3
    end
    
    return S3
end

--[[Function will not resolve character aliases because it's uncommon for characters to have an actual name and an alias. Moreover,
looking up characters by their normalized-canonical name doesn't provide the same possible performance/usability enhancements as using the
normalized-canonical forms of property names and property values.]]
--Related to above, does not currently validate that the given name actually exists. Haven't decided on what behavior I want yet.
function export.CharacterName ( str )
    assert( IsValidName( str ) ) --TODO: Needs to not use assert but more proper checking
    return NormalizeCharacterName_Advanced( str )
end

local function NormalizePropertyName ( str )
    assert( IsValidName( str ) ) --TODO: Needs to not use assert but more proper checking
    return str:gsub("[%s_%-]+", ""):lower()
end

--TODO: Does not currently error for non-existent properties. Haven't decided on what behavior I want yet.
local PropertyAliasesTable = require "us4l.internals.PropertyAliasesTable"
function export.PropertyName ( str )
    str = NormalizePropertyName( str )
    local alias = PropertyAliasesTable[ str ]
    return alias or str
end

local function NormalizePropertyValue ( str )
    assert( IsValidName( str ) ) --TODO: Needs to not use assert but more proper checking
    local S1 = str:gsub("[%s_%-]+", ""):lower()
    local S1i = S1
    repeat
        S1i = S1
        S1 = S1i:gsub( "^is", "" )
    until #S1 == #S1i
    return S1
end

--TODO: Does not currently error for non-existent property names or values. Haven't decided on what behavior I want yet.
--Function might not necessarily return string, could also return boolean.
local PropertyValueAliasesTable = require "us4l.internals.PropertyValueAliasesTable"
local e_NormalizePropertyName = export.PropertyName
function export.PropertyValue ( prop_name, prop_val )
    prop_name = e_NormalizePropertyName( prop_name )
    prop_val = NormalizePropertyValue( prop_val )
    local prop_aliases = PropertyValueAliasesTable[ prop_name ]
    if prop_aliases then
        local canon_val = prop_aliases[ prop_val ]
        if canon_val ~= nil then
            return canon_val
        end
    end
    return prop_val
end

return export