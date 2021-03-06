<# Proceses Unihan_NumericValues.txt
    This adds Numeric_Type and Numeric_Value for many characters, as well as kAccountingNumeric, kOtherNumeric, and kPrimaryNumeric
#>

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
    Import-Module .\Normalize.psm1
    Import-Module .\Progress.psm1
    Import-Module .\FileUtilities.psm1
    Import-Module .\CharacterObject.psm1
    
    $UHNVR = Get-StreamReader Unihan\Unihan_NumericValues.txt
    [String]$CurLine = $UHNVR.ReadNonCommentLine()
    $CP_Str, $Cat, $Val_Str = $CurLine -split "`t"
    [UInt32]$CP = [UInt32]::Parse( $CP_Str.Substring(2), 'AllowHexSpecifier' )
    
    $NumericTypeKV = New-Object LuaKV (Normalize-PropertyName Numeric_Type), (New-Object LuaString (Normalize-PropertyValueName Numeric_Type Numeric), Long)
    $LuaTrueVal = New-Object LuaBoolean $True
}

Process
{
    ForEach ( $Character in $InputCharacter )
    {
        $CharCP = $Character.cp
        
        If ( $CP -eq $CharCP )
        {
            Add-CharacterProperty $Character $NumericTypeKV
            
            $NumericValue = New-Object LuaInteger ([Int64]::Parse( $Val_Str )), 'Decimal'
            $NumericValueKV = New-Object LuaKV (Normalize-PropertyName Numeric_Value), $NumericValue
            Add-CharacterProperty $Character $NumericValueKV
            
            $OtherNumericTypeKey = New-Object LuaString (Normalize-PropertyName $Cat), 'Identifier'
            $OtherNumericTypeKV = New-Object LuaKV $OtherNumericTypeKey, $LuaTrueVal
            Add-CharacterProperty $Character $OtherNumericTypeKV
            
            # And update to next line
            If ( [String]::IsNullOrEmpty(($CurLine = $UHNVR.ReadNonCommentLine())) ) # I don't know why changing to this away from checking for $Null solved my problem, because I don't know what was causing the problem in the first place.
            {
                $CP = [UInt32]::MaxValue
            }
            Else
            {
                $CP_Str, $Cat, $Val_Str = $CurLine -split "`t"
                $CP = [UInt32]::Parse( $CP_Str.Substring(2), 'AllowHexSpecifier' )
                Trap
                {
                    Write-Error ("Error: CP_Str=$CP_Str, CurLine='$CurLine', CharCP=$CharCP")
                }
            }
        }
        
        $Character | Write-Output
    }
}