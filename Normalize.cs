using STRE = System.Text.RegularExpressions;
using System;

public static class Normalize
{
    private static String RegexReplace ( this String In, String Patt, String Rep )
    {
        return STRE.Regex.Replace( In, Patt, Rep );
    }
    
    private static String CharacterNameBasic ( String In )
    {
        // TODO: Assert proper format of input string.
        
        /* For uniformity, flank the string with underscores, then replace any sequence of whitespace and underscores with a single
           underscore, then lowercase the string. */
        String S1 = ( "_" + In + "_" )
            .RegexReplace( @"[\s_]+", "_" )
            .ToLower();
        
        /* Protect non-medial hyphens, remove medial hyphens, protect spaces adjacent to non-medial hyphens, remove spaces,
           then unprotect any hyphens or spaces */
        String S2 = S1
            .Replace( "o-e", "o#e" )
            .RegexReplace( @"(?<=[a-z\d])\-(?=[a-z\d])", "" )
            .Replace( "_-", "%#" )
            .RegexReplace( @"[#\-]_", "#%" )
            .Replace( "_", "" )
            .Replace( '#', '-' )
            .Replace( '%', '_' );
        
        // If string doesn't match "hanguljungseongo-e", then remove any remaining medial hyphens.
        if ( S2 != "hanguljungseongo-e" )
            S2 = S2.RegexReplace( "(?<!_)-", "" );
        
        return S2;
    }
    
    private static String CharacterNameAdvanced ( String In )
    {
        // Recursively remove all instances of "letter", "character", and "digit" until nothing gets shortened, check for "CANCEL CHARACTER"
        String S2 = CharacterNameBasic( In );
        
        String S3 = S2;
        String S3i = S3;
        do
        {
            S3i = S3;
            S3 = S3i.Replace( "letter", "" ).Replace( "character", "" ).Replace( "digit", "" );
        } while ( S3i.Length > S3.Length );
        
        if ( S3 == "cancel" )
        {
            S3 = S2;
            do
            {
                S3i = S3;
                S3 = S3i.Replace( "letter", "" ).Replace( "digit", "" );
            } while ( S3i.Length > S3.Length );
        }
        
        return S3;
    }
    
    public static String CharacterName ( String In )
    {
        return CharacterNameAdvanced( In ); // Could be changed to CharacterNameBasic depending on how the committee decides things.
    }
    
    public static String PropertyName ( String In )
    {
        return In.RegexReplace( @"[\s_\-]", "" ).ToLower();
    }
    
    public static String PropertyValue ( String In )
    {
        String S1 = In.RegexReplace( @"[\s_\-]", "" ).ToLower();
        String S1i = S1;
        do
        {
            S1i = S1;
            S1 = S1i.RegexReplace( "^is", "" );
        } while ( S1i.Length > S1.Length );
        return S1;
    }
}