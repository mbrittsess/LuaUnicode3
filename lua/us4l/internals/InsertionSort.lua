--TODO: Just the function is written here, it needs to be actually exported and documented properly

local function ins_sort_inplace ( in_arr, cmp_func, s_idx, e_idx )
    s_idx = s_idx or 1
    e_idx = e_idx or #in_arr
    cmp_func = cmp_func or function ( A, B ) return A <= B end
    for cand_idx = s_idx+1, e_idx do
        local cand = in_arr[ cand_idx ]
        for place_idx = cand_idx, s_idx+1, -1 do
            local other = in_arr[ place_idx-1 ]
            if not cmp_func( other, cand ) then
                in_arr[ place_idx ] = other
                in_arr[ place_idx-1 ] = cand
            else
                break
            end
        end
    end
end

return ins_sort_inplace