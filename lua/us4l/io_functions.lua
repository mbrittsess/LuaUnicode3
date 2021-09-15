--This file is temporary and here to hold potential implementations of various file I/O functions

local read_all_str, read_number_str, read_line_str, read_line_term_str
if LuaVersion == "Lua53" or LuaVersion == "Lua54" then
    read_all_str, read_number_str, read_line_str, read_line_term_str = "a", "n", "l", "L"
else
    read_all_str, read_number_str, read_line_str, read_line_term_str = "*a", "*n", "*l", "*L"
end

local utf8_bom = string.char( 0xEF, 0xBB, 0xBF )

function utf8_system_method:ReadAll ( )
    if self.AtEOF then
        return EmptyUString
    elseif self.IsError then
        return nil, self.IsErrorMessage
    else
        local WasAtBeginning = self.AtBeginning
        local ret = self.InternalFile:read( read_all_str )
        self.AtEOF, self.AtBeginning = true, false
        if ret == "" then
            return EmptyUString
        end
        if WasAtBeginning and self.SkipBom and ret:sub(1, #utf8_bom) == utf8_bom then
            ret = ret:sub(#utf8_bom+1, -1)
        end
        return self.DecodeString( ret ) --Different implementations, some never fail and others could return nil+err
    end
end

if LuaVersion == "Lua51" or LuaVersion == "LuaJIT" then
    --Calls file:read( "*l" ) .. "\n", regardless of system-specific line ending
    function utf8_system_method:ReadLine ( include_term )
        if self.AtEOF then
            return nil
        elseif self.IsError then
            return nil, self.IsErrorMessage
        else
            local WasAtBeginning = self.AtBeginning
            local ret = self.InternalFile:read( read_line_str )
            self.AtBeginning = false
            if not ret then
                self.AtEOF = true
                return nil
            end
            if WasAtBeginning and self.SkipBom and ret:sub(1, #utf8_bom) == utf8_bom then
                ret = ret:sub(#utf8_bom+1, -1)
            end
            if include_term then
                ret = ret .. "\n"
            end
            return self.DecodeString( ret )
        end
    end
else
    --Calls file:read( "*L" )
    function utf8_system_method:ReadLine ( include_term )
        if self.AtEOF then
            return nil
        elseif self.IsError then
            return nil, self.IsErrorMessage
        else
            local WasAtBeginning = self.AtBeginning
            local ret = self.InternalFile:read( include_term and read_line_term_str or read_line_str )
            self.AtBeginning = false
            if not ret then
                self.AtEOF = true
                return nil
            end
            if WasAtBeginning and self.SkipBom and ret:sub(1, #utf8_bom) == utf8_bom then
                ret = ret:sub(#utf8_bom+1, -1)
            end
            return self.DecodeString( ret )
        end
    end
end

function utf8_system_method:ReadNumber ( )
    if self.AtEOF then
        return nil
    elseif self.IsError then
        return nil, self.IsErrorMessage
    else
        local WasAtBeginning = self.AtBeginning
        if WasAtBeginning and self.SkipBom then --Have to try and skip BOM using file-seeking
            local initial = self.InternalFile:read( #utf8_bom )
            if initial == utf8_bom then
                local res, err_msg = self.InternalFile:seek( "set", #utf8_bom )
                if not res then
                    self.IsError = true
                    self.IsErrorMessage = string.format( "Tried to read number at beginning of non-seekable stream with SkipBom=true (%s)", err_msg )
                    return nil
                end
            end
        end
        self.AtBeginning = false
        return self.InternalFile:read( read_number_str )
    end
end

--This might be identical to the regular version of this function?
--Almost, but self.GetCharacter() won't buffer anything
function utf8_system_method:ReadCharacters ( num ) --Argument has already been validated
    if self.AtEOF then
        return nil
    elseif num == 0 then
        return EmptyUString
    else
        local WasAtBeginning = self.AtBeginning
        self.AtBeginning = false
        local ret_cp_list = {}
        local GetCharacter = self.GetCharacter
        if WasAtBeginning and self.SkipBom then
            local first_cp, err_msg = GetCharacter(self)
            if first_cp == nil then
                self.IsError = true
                self.IsErrorMessage = err_msg
                return nil
            elseif first_cp ~= 0xFEFF then
                ret_cp_list[ 1 ] = first_cp
                num = num-1
            end
        end
        local ofs = #ret_cp_list
        for i = 1, num do
            local cp, err_msg = GetCharacter(self)
            if not cp then
                self.IsError = true
                self.IsErrorMessage = err_msg
                return nil
            end
            ret_cp_list[ ofs+i ] = cp
        end
        return MakeUString( ret_cp_list )
    end
end