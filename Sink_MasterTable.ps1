Param
(
    [Parameter(
        Mandatory=$True,
        ValueFromPipeline=$True)]
    [PSObject[]]
    $InputCharacter
)

Begin
{
    Import-Module .\CompileCS.psm1
    Import-Module .\Normalize.psm1
    Import-Module .\Progress.psm1
    
    Remove-Item lua\us4l\internals\MasterTable\Init_Plane*.lua
    If ( Test-Path lua\us4l\internals\MasterTable\InitAllChunks.lua )
    {
        Remove-Item lua\us4l\internals\MasterTable\InitAllChunks.lua
    }
    
    $PlaneNames = New-Object System.Collections.ArrayList
    
    Function New-ChunkWriter ( [UInt32]$Plane, [UInt32]$ChunkNumber )
    {
        $PlaneName = "Init_Plane{0}_{1}" -f $Plane, $ChunkNumber
        $Writer = New-Object System.IO.StreamWriter ("lua\us4l\internals\MasterTable\{0}.lua" -f $PlaneName), $False, ([System.Text.Encoding]::ASCII)
        [Void]$PlaneNames.Add( $PlaneName )
        $OutObj = New-Object PSObject -Property @{
            Writer = $Writer;
            Plane  = $Plane;
            Chunk  = $Chunk;
        } | Add-Member ScriptMethod Begin { 
            $InitHeader = @"
local InitFuncs = require "us4l.internals.MasterTable.InitFunctions"

local UCharInit = InitFuncs.UCharInit

"@
            $InitHeader -split "`n" | ForEach-Object {
                $This.Writer.WriteLine( $_.Trim() )
            }
        } -PassThru | Add-Member ScriptMethod Write {
            Param( [String]$Value )
            $This.Writer.WriteLine( $Value )
        } -PassThru | Add-Member ScriptMethod End {
            $This.Writer.Close()
        } -PassThru | Add-Member ScriptMethod EndWithContinue {
            # Doesn't do anything different now, but used to, and might in the future.
            $This.End()
        } -PassThru
        $OutObj.Begin()
        $OutObj | Write-Output
    }
    
    <#
    Function FormatCharOutput ( [PSObject]$Character )
    {
        [String[]]$InitialProperties = "codepoint", "name"
        [String[]]$OtherProperties = $Character.properties.Keys | Where-Object { $InitialProperties -notcontains $_ }
        [String[]]$PropertyNames = @( $InitialProperties + $OtherProperties ) | Where-Object { $Character.properties.ContainsKey( $_ ) }
        $Contents = @( $PropertyNames | ForEach-Object { $Character.properties[ $_ ].ToString() } ) -join ' '
        Return 'UCharInit{{ {0} }}' -f $Contents
    }
    #>
    
    Function FormatCharOutput ( [PSObject]$Character )
    {
        $Properties = $Character.properties.Clone()
        [LuaKV]$CpKV = $Properties[ "codepoint" ]
        [LuaKV]$NameKV = $Properties[ "name" ]
        $Properties.Remove( "codepoint" )
        $Properties.Remove( "name" )
        [LuaKV[]]$RegularProperties = @()
        [LuaKV[]]$UStringProperties = @()
        $Properties.Values | ForEach-Object {
            If ( $_.Value -is [LuaUString] )
            {
                $UStringProperties += $_
            }
            Else
            {
                $RegularProperties += $_
            }
        }
        [LuaKV[]]$RegularProperties = & {
            $CpKV
            $NameKV
            $RegularProperties
        } | Where-Object { $_ -ne $Null }
        $RegularPropertiesContents = @( $RegularProperties | ForEach-Object { $_.ToString() } ) -join ' '
        $UStringPropertiesContents = @( $UStringProperties | ForEach-Object {
            $Key = $_.Key.Value
            $Value = $_.Value.ToStringAsValue().Substring(1)
            "{0} = {1};" -f $Key, $Value
        } ) -join ' '
        If ( $UStringProperties.Count -eq 0 )
        {
            'UCharInit{{ {0} }}' -f $RegularPropertiesContents
        }
        Else
        {
            'UCharInit{{ {0} {{ {1} }} }}' -f $RegularPropertiesContents, $UStringPropertiesContents
        }
    }
    
    $PlaneNumber = 0
    $ChunkNumber = 1
    $ChunkWriter = New-ChunkWriter $PlaneNumber $ChunkNumber
    $ConstantCounter = New-Object LuaConstantsCounter
    $ConstantLimit = 30000
    $NeedCloseChunk = $False
    #$ChunkWriter.Begin()
}

Process
{
    ForEach ( $Character in $InputCharacter )
    {
        $Plane = [Math]::Floor( $Character.cp / 0x10000 )
        If ( $Plane -ne $PlaneNumber )
        {
            $ChunkWriter.End()
            $PlaneNumber = $Plane
            $ChunkNumber = 1
            $ConstantCounter = New-Object LuaConstantsCounter
            $NeedCloseChunk = $False
            $ChunkWriter = New-ChunkWriter $PlaneNumber $ChunkNumber
        }
        
        If ( $NeedCloseChunk )
        {
            $ChunkWriter.EndWithContinue()
            $ConstantCounter = New-Object LuaConstantsCounter
            $NeedCloseChunk = $False
            $ChunkWriter = New-ChunkWriter $PlaneNumber (++$ChunkNumber)
        }
        
        ForEach ( $Property in $Character.properties.Values )
        {
            $ConstantCounter.Add( $Property.Key )
            If ( $Property.Value -isnot [LuaUString] -and $Property.Value -isnot [LuaMixedTable] -and $Property.Value -isnot [LuaRational] ) # TODO: Check if there's a cleaner way to do this
            {
                $ConstantCounter.Add( $Property.Value )
            }
        }
        $Val = FormatCharOutput $Character
        $ChunkWriter.Write( $Val )
        If ( $ConstantCounter.TotalConstants -gt $ConstantLimit )
        {
            $NeedCloseChunk = $True
        }
        #Write-Host ("Plane {0}, Chunk {1}, Constants: {2}, Table Entry: {3}" -f $PlaneNumber, $ChunkNumber, $ConstantCounter.TotalConstants, $Val)
    }
}

End
{
    $ChunkWriter.End()
    
    & {
        "local ChunkInitNames = {"
        & {
            $PlaneNames[ 0 .. ($PlaneNames.Count-2) ] | ForEach-Object { '"us4l.internals.MasterTable.{0}",' -f $_ }
            '"us4l.internals.MasterTable.{0}"' -f $PlaneNames[ $PlaneNames.Count-1 ]
        } | ForEach-Object {
            "    " + $_
        }
        "}"
        ""
        "for _,ChunkInitName in ipairs( ChunkInitNames ) do"
        "    require( ChunkInitName )"
        "end"
        ""
        "require( ""us4l.internals.MasterTable.InitFunctions"" ).ProcessDeferredUStrings()"
    } | Out-File -FilePath lua\us4l\internals\MasterTable\InitAllChunks.lua -Encoding ASCII
}