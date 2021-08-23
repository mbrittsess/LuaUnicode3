--us4l.io sub-module, equivalent to Lua's standard io module

local export = {}

local function NotImplementedYet ( ) return error "Not implemented yet" end

function export.close ( file )
    NotImplementedYet()
end

function export.flush ( )
    NotImplementedYet()
end

function export.lines ( filename, ... )
    NotImplementedYet()
end

function export.openread ( filename, params )
    NotImplementedYet()
end

function export.openwrite ( filename, params )
    NotImplementedYet()
end

function export.openappend ( filename, params )
    NotImplementedYet()
end

function export.read ( ... )
    NotImplementedYet()
end

function export.tmpfile ( params )
    NotImplementedYet()
end

function export.type ( obj )
    NotImplementedYet()
end

function export.write ( ... )
    NotImplementedYet()
end

export.stdin = nil
export.stdout = nil
export.stderr = nil

return export