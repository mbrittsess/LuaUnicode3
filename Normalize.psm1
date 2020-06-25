Import-Module .\CompileCS.psm1
Import-Module .\Progress.psm1

# TODO: This is only for the UCD, not Unicode in its entirety
[String[]]$CompletePropertyList = "Joining_Type",
    "Joining_Group",
    "Bidi_Paired_Bracket_Type",
    "Bidi_Paired_Bracket",
    "Bidi_Mirroring_Glyph",
    "Block",
    "Composition_Exclusion",
    "Simple_Case_Folding",
    "Case_Folding",
    "Age",
    "East_Asian_Width",
    "Equivalent_Unified_Ideograph",
    "Hangul_Syllable_Type",
    "Indic_Positional_Category",
    "Indic_Syllabic_Category",
    "Jamo_Short_Name",
    "Line_Break",
    "Grapheme_Cluster_Break",
    "Sentence_Break",
    "Word_Break",
    "Name_Alias",
    "Script",
    "Script_Extensions",
    "Uppercase_Mapping",
    "Lowercase_Mapping",
    "Titlecase_Mapping",
    "Numeric_Type",
    "Numeric_Value",
    "Unicode_Radical_Stroke",
    "Lowercase",
    "Uppercase",
    "Cased",
    "Changes_When_Lowercased",
    "Changes_When_Uppercased",
    "Changes_When_Titlecased",
    "Changes_When_Casefolded",
    "Changes_When_Casemapped",
    "Alphabetic",
    "Default_Ignorable_Code_Point",
    "Grapheme_Base",
    "Grapheme_Extend",
    "Grapheme_Link",
    "Math",
    "ID_Start",
    "ID_Continue",
    "XID_Start",
    "XID_Continue",
    "Full_Composition_Exclusion",
    "Expands_On_NFC",
    "Expands_On_NFD",
    "Expands_On_NFKC",
    "Expands_On_NFKD",
    "FC_NFKC_Closure",
    "NFD_Quick_Check",
    "NFKD_Quick_Check",
    "NFC_Quick_Check",
    "NFKC_Quick_Check",
    "NFKC_Casefold",
    "Changes_When_NFKC_Casefolded",
    "ASCII_Hex_Digit",
    "Bidi_Control",
    "Dash",
    "Deprecated",
    "Diacritic",
    "Extender",
    "Hex_Digit",
    "Hyphen",
    "Ideographic",
    "IDS_Binary_Operator",
    "IDS_Trinary_Operator",
    "Join_Control",
    "Logical_Order_Exception",
    "Noncharacter_Code_Point",
    "Other_Alphabetic",
    "Other_Default_Ignorable_Code_Point",
    "Other_Grapheme_Extend",
    "Other_ID_Continue",
    "Other_ID_Start",
    "Other_Lowercase",
    "Other_Math",
    "Other_Uppercase",
    "Pattern_Syntax",
    "Pattern_White_Space",
    "Prepended_Concatenation_Mark",
    "Quotation_Mark",
    "Radical",
    "Regional_Indicator",
    "Sentence_Terminal",
    "Soft_Dotted",
    "Terminal_Punctuation",
    "Unified_Ideograph",
    "Variation_Selector",
    "White_Space",
    "Name",
    "General_Category",
    "Canonical_Combining_Class",
    "Bidi_Class",
    "Decomposition_Type",
    "Decomposition_Mapping",
    "Numeric_Type",
    "Numeric_Value",
    "Bidi_Mirrored",
    "Unicode_1_Name",
    "ISO_Comment",
    "Simple_Uppercase_Mapping",
    "Simple_Lowercase_Mapping",
    "Simple_Titlecase_Mapping",
    "Vertical_Orientation"

[Hashtable[]]$CorePropertyList = @()

<#
Get-Content UCD\PropertyAliases.txt | Where-Object {
    $_ -ne "" -and $_[0] -ne '#'
} | ForEach-Object {
    [String]$FirstAlias, [String]$FormalName, [String[]]$OtherAliases = $_ -split ';' | %{ $_.Trim() }

    [String[]]$FormalAliases = @( [String[]]$FirstAlias + ($OtherAliases | ?{ -not [String]::IsNullOrEmpty( $_ ) } ) )

    $CorePropertyList += @{
        FormalName = $FormalName;
        FormalAliases = $FormalAliases;
        AllNames = @( [String[]]$FormalName + $FormalAliases ) | %{ [Normalize]::PropertyName( $_ ) } | Sort-Object -Unique
    }
}
#>
$AliasProgress = New-RootProgress "Building Property Alias table"
$ValuesProgress = New-RootProgress "Building Property Value Alias table"

$AliasReader = New-Object System.IO.StreamReader UCD\PropertyAliases.txt
$AliasProgress.OverallStatus = "Processing UCD\PropertyAliases.txt"
While ( -not $AliasReader.EndOfStream )
{
    $Line = $AliasReader.ReadLine()
    If ( $Line -eq "" -or $Line[0] -eq '#' )
    {
        Continue
    }
    
    [String]$FirstAlias, [String]$FormalName, [String[]]$OtherAliases = $Line -split ';' | %{ $_.Trim() }
    $Progress = $AliasReader.BaseStream.Position / $AliasReader.BaseStream.Length
    
    $AliasProgress.CurrentOperation = "Processing aliases of {0}" -f $FormalName
    $AliasProgress.Update( $Progress )
    
    [String[]]$FormalAliases = @( [String[]]$FirstAlias + ($OtherAliases | ?{ -not [String]::IsNullOrEmpty( $_ ) } ) )

    $CorePropertyList += @{
        FormalName = $FormalName;
        FormalAliases = $FormalAliases;
        AllNames = @( [String[]]$FormalName + $FormalAliases ) | %{ [Normalize]::PropertyName( $_ ) } | Sort-Object -Unique
    }
}
$AliasProgress.OverallStatus = "Done"
$AliasProgress.CurrentOperation = ""
$AliasProgress.Update( 1.0 )

$AliasesTable = New-Object 'System.Collections.Generic.Dictionary[String,Hashtable]'
ForEach ( $AliasInfo in $CorePropertyList )
{
    ForEach ( $NormName in $AliasInfo.AllNames )
    {
        $AliasesTable.Add( $NormName, $AliasInfo )
    }
}

$UnihanPropertyNames = "kAccountingNumeric", "kBigFive", "kCangjie", "kCantonese", "kCCCII", "kCheungBauer", "kCheungBauerIndex", "kCihaiT",
    "kCNS1986", "kCNS1992", "kCompatibilityVariant", "kCowles", "kDaeJaweon", "kDefinition", "kEACC", "kFenn", "kFennIndex",
    "kFourCornerCode", "kFrequency", "kGB0", "kGB1", "kGB3", "kGB5", "kGB7", "kGB8", "kGradeLevel", "kGSR", "kHangul", "kHanYu",
    "kHanyuPinlu", "kHanyuPinyin", "kHDZRadBreak", "kHKGlyph", "kHKSCS", "kIBMJapan", "kIICore", "kIRG_GSource", "kIRG_HSource",
    "kIRG_JSource", "kIRG_KPSource", "kIRG_KSource", "kIRG_MSource", "kIRG_TSource", "kIRG_USource", "kIRG_VSource", "kIRGDaeJaweon",
    "kIRGDaiKanwaZiten", "kIRGHanyuDaZidian", "kIRGKangXi", "kJa", "kJapaneseKun", "kJapaneseOn", "kJinmeiyoKanji", "kJis0", "kJis1",
    "kJIS0213", "kJoyoKanji", "kKangXi", "kKarlgren", "kKorean", "kKoreanEducationHanja", "kKoreanName", "kKPS0", "kKPS1", "kKSC0", "kKSC1",
    "kLau", "kMainlandTelegraph", "kMandarin", "kMatthews", "kMeyerWempe", "kMorohashi", "kNelson", "kOtherNumeric", "kPhonetic",
    "kPrimaryNumeric", "kPseudoGB1", "kRSAdobe_Japan1_6", "kRSJapanese", "kRSKangXi", "kRSKanWa", "kRSKorean", "kRSUnicode", "kSBGY",
    "kSemanticVariant", "kSimplifiedVariant", "kSpecializedSemanticVariant", "kTaiwanTelegraph", "kTang", "kTGH", "kTotalStrokes",
    "kTraditionalVariant", "kVietnamese", "kXerox", "kXHC1983", "kZVariant"
ForEach ( $FormalName in $UnihanPropertyNames )
{
    $NormName = [Normalize]::PropertyName( $FormalName )
    If ( -not $AliasesTable.ContainsKey( $NormName ) )
    {
        $AliasInfo = @{
            FormalName = $FormalName;
            FormalAliases = [String[]]@( $FormalName );
            AllNames = [String[]]@( $NormName );
        }
        $AliasesTable.Add( $NormName, $AliasInfo )
    }
}

#TODO: Bit of a hack. Must re-design this file.
ForEach ( $FormalName in $CompletePropertyList )
{
    $NormName = [Normalize]::PropertyName( $FormalName )
    If ( -not $AliasesTable.ContainsKey( $NormName ) )
    {
        $AliasInfo = @{
            FormalName = $FormalName;
            FormalAliases = [String[]]@( $FormalName );
            AllNames = [String[]]@( $NormName );
        }
        $AliasesTable.Add( $NormName, $AliasInfo )
    }
}

Function Normalize-PropertyName
{
    [CmdletBinding()]
    
    Param
    (
        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name,
        
        #Used when you don't want to map from aliases to formal names
        [Switch]
        $NoExpand
    )
    
    $Ret = [Normalize]::PropertyName( $Name )
    If ( -not $AliasesTable.ContainsKey( $Ret ) )
    {
        #TODO: Need to come up with a better exception, maybe
        Throw New-Object ArgumentException "Bad argument to Name: '$Name' is not a valid property name or property name alias."
    }
    If ( -not $NoExpand )
    {
        $Ret = [Normalize]::PropertyName( $AliasesTable[ $Ret ].FormalName )
    }
    
    Return $Ret
}

#Now we will build the value-alias table
<#
Get-Content UCD\PropertyValueAliases.txt | Where-Object {
    $_ -ne "" -and $_[0] -ne '#'
} | ForEach-Object {
    [String]$PropertyName, [String[]]$ValueNames = $_ -split ';' | %{ $_.Trim() }
    
    # NOTE: FOR PROPERTY 'ccc', THE LOCATION OF THE FORMAL NAME IS DIFFERENT
    $NameIdx = $( If ( $PropertyName -ne 'ccc' ) { 1 } Else { 2 } )
    $FormalName = $ValueNames[ $NameIdx ]
    [String[]]$FormalAliases = $ValueNames[ @(0 .. ($ValueNames.Count-1) | ?{ $_ -ne $NameIdx } ) ]
    
    $ValueDescription = @{
        FormalName = $FormalName;
        FormalAliases = $FormalAliases;
        AllNames = @( [String[]]$FormalName + $FormalAliases ) | %{ [Normalize]::PropertyValue( $_ ) } | Sort-Object -Unique
    }
    
    $PropertyInfo = $AliasesTable[ (Normalize-PropertyName $PropertyName) ]
    If ( -not $PropertyInfo.ContainsKey( 'ValuesTable' ) )
    {
        $PropertyInfo.Add( 'ValuesTable', (New-Object 'System.Collections.Generic.Dictionary[String,Hashtable]') )
    }
    $ValuesTable = $PropertyInfo.ValuesTable
    
    ForEach ( $Name in $ValueDescription.AllNames )
    {
        $ValuesTable.Add( $Name, $ValueDescription )
    }
}
#>
$ValuesReader = New-Object System.IO.StreamReader UCD\PropertyValueAliases.txt, UTF8
$ValuesProgress.OverallStatus = "Processing UCD\PropertyValueAliases.txt"
While (-not $ValuesReader.EndOfStream )
{
    $Line = $ValuesReader.ReadLine()
    If ( $Line -eq "" -or $Line[0] -eq '#' )
    {
        Continue
    }
    
    [String]$PropertyName, [String[]]$ValueNames = $Line -split ';' | %{ $_.Trim() }
    
    # NOTE: FOR PROPERTY 'ccc', THE LOCATION OF THE FORMAL NAME IS DIFFERENT
    $NameIdx = $( If ($PropertyName -ne 'ccc' ) { 1 } Else { 2 } )
    $FormalName = $ValueNames[ $NameIdx ]
    [String[]]$FormalAliases = $ValueNames[ @(0 .. ($ValueNames.Count-1) | ?{ $_ -ne $NameIdx } ) ]
    
    $ValueDescription = @{
        FormalName = $FormalName;
        FormalAliases = $FormalAliases;
        AllNames = @( [String[]]$FormalName + $FormalAliases ) | %{ [Normalize]::PropertyValue( $_ ) } | Sort-Object -Unique
    }
    
    $PropertyInfo = $AliasesTable[ (Normalize-PropertyName $PropertyName) ]
    If ( -not $PropertyInfo.ContainsKey( 'ValuesTable' ) )
    {
        $PropertyInfo.Add( 'ValuesTable', (New-Object 'System.Collections.Generic.Dictionary[String,Hashtable]') )
    }
    $ValuesTable = $PropertyInfo.ValuesTable
    
    $ValuesProgress.CurrentOperation = "Processing aliases of value {0} of {1}" -f $FormalName, $PropertyInfo.FormalName
    $ValuesProgress.Update( $ValuesReader.BaseStream.Position / $ValuesReader.BaseStream.Length )
    
    ForEach ( $Name in $ValueDescription.AllNames )
    {
        $ValuesTable.Add( $Name, $ValueDescription )
    }
}
$ValuesProgress.OverallStatus = "Done"
$ValuesProgress.CurrentOperation = ""
$ValuesProgress.Update( 1.0 )

Function Normalize-PropertyValueName
{
    [CmdletBinding()]
    
    Param
    (
        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [String]
        $PropertyName,
        
        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Value,
        
        #Used when you don't want to map from aliases to formal names
        [Switch]
        $NoExpand
    )
    
    $NormPropertyName = Normalize-PropertyName $PropertyName
    $PropInfo = $AliasesTable[ $NormPropertyName ]
    $NormValue = [Normalize]::PropertyValue( $Value )
    If ( $PropInfo.ContainsKey( 'ValuesTable' ) )
    {
        $ValuesTable = $PropInfo.ValuesTable
        If ( -not $ValuesTable.ContainsKey( $NormValue ) )
        {
            #TODO: Need to come up with a better exception, maybe
            Throw New-Object ArgumentException "Bad argument to Value: '$Value' is not a valid property value name or property value name alias for property '$PropertyName'."
        }
        If ( -not $NoExpand )
        {
            Return [Normalize]::PropertyValue( $ValuesTable[ $NormValue ].FormalName )
        }
    }
    Return $NormValue
}

#TODO: Create Get-FormalPropertyName and Get-FormalPropertyValueName
Export-ModuleMember -Function Normalize-PropertyName, Normalize-PropertyValueName