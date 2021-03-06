$Doc = New-Object System.Xml.XmlDocument
$Doc.Load( ".\JMdict_e" )
[Xml.XmlElement[]]$Entries = $Doc.JMdict[1].entry

$Global:NumEntries = 0

& {
    ForEach( $Entry in $Entries )
    {
        If ( $Entry.k_ele -ne $Null )
        {
            [Xml.XmlElement[]]$KanjiEntries = $Entry.k_ele
            ForEach ( $KanjiEntry in $KanjiEntries )
            {
                $KanjiEntry.keb | Write-Output
            }
        }
        
        <#
        If ( $Entry.r_ele -ne $Null )
        {
            [Xml.XmlElement[]]$ReadingEntries = $Entry.r_ele
            ForEach ( $ReadingEntry in $ReadingEntries )
            {
                $ReadingEntry.reb | Write-Output
            }
        }
        #>
    }
} | ForEach-Object { $Global:NumEntries += 1; $_ | Write-Output } | Out-File -FilePath jp_words.txt -Encoding UTF8