using System;
using System.Collections.Generic;
using System.Text;
using System.Text.RegularExpressions;
using System.Linq;

public class LuaConstantsCounter
{
    private HashSet<String> StringsEncountered; private UInt32 NumStrings = 0;
    private HashSet<Int64> IntegersEncountered; private UInt32 NumIntegers = 0;
    private HashSet<Double> RealsEncountered; private UInt32 NumReals = 0;
    
    // We don't bother counting booleans or nils at this point
    public UInt32 TotalConstants { get { return NumStrings + NumIntegers + NumReals; } }
    
    public void Add ( LuaNil Val     ) { }
    public void Add ( LuaBoolean Val ) { }
    public void Add ( LuaInteger Val ) { NumIntegers += IntegersEncountered.Add( Val.Value ) ? 1U : 0U; }
    public void Add ( LuaReal Val    ) { NumReals += RealsEncountered.Add( Val.Value )       ? 1U : 0U; }
    public void Add ( LuaString Val  ) { NumStrings += StringsEncountered.Add( Val.Value )   ? 1U : 0U; }
    
    //This is a travesty. Value of 2 chosen based on an average of the number of aliases each character has.
    public void Add ( LuaMixedTable Val ) { NumStrings += 2U; }
    
    public LuaConstantsCounter ( )
    {
        StringsEncountered = new HashSet<String>();
        IntegersEncountered = new HashSet<Int64>();
        RealsEncountered = new HashSet<Double>();
    }
}

public class LuaKV
{
    private readonly LuaValue _Key, _Value;
    
    public LuaValue Key { get { return _Key; } }
    public LuaValue Value { get { return _Value; } }
    
    public override String ToString ( )
    {
        return String.Format( "{0} = {1};", Key.ToStringAsKey(), Value.ToStringAsValue() );
    }
    
    public LuaKV ( LuaValue Key, LuaValue Value ) { _Key = Key; _Value = Value; }
    public LuaKV ( String Key, LuaValue Value ) :this( new LuaString( Key, LuaStringStyle.Identifier ), Value ) { }
}

public abstract class LuaValue
{
    public abstract String ToStringAsValue ( );
    public virtual String ToStringAsKey ( Int32 padding )
    {
        String V = AsKey();
        if      ( padding < 0 )
            V = V.PadRight( Math.Abs( padding ) );
        else if ( padding > 0 )
            V = V.PadLeft( padding );
        return String.Concat( '[', V, ']' );
    }
    public         String ToStringAsKey ( ) { return ToStringAsKey( 0 ); }
    
    protected virtual String AsKey ( )
    {
        return ToStringAsValue();
    }
    
    public override String ToString ( )
    {
        return String.Concat( this.GetType().Name, ':', this.ToStringAsValue() );
    }
}

public class LuaNil : LuaValue
{
    
    public override String ToStringAsValue ( ) { return "nil"; }
    
    public LuaNil ( ) { }
}

public class LuaBoolean : LuaValue
{
    private readonly Boolean _Value;
    
    public Boolean Value { get { return _Value; } }
    
    public override String ToStringAsValue ( )
    {
        return _Value ? "true" : "false";
    }
    
    public LuaBoolean ( Boolean v )
    {
        _Value = v;
    }
}

// Does nothing, but we may add stuff here later
public abstract class LuaNumber : LuaValue
{
}

public enum LuaIntegerStyle {
    Decimal, Hexadecimal, CodePoint }
public class LuaInteger : LuaNumber
{
    private readonly Int64 _Value;
    private readonly LuaIntegerStyle Style = LuaIntegerStyle.Decimal;
    
    public Int64 Value { get { return _Value; } }
    
    public override String ToStringAsValue ( )
    {
        switch ( Style )
        {
            case LuaIntegerStyle.Decimal :
                return _Value.ToString("D");
            case LuaIntegerStyle.Hexadecimal :
                return "0x" + _Value.ToString("X");
            case LuaIntegerStyle.CodePoint :
                return "0x" + _Value.ToString("X4");
        }
        throw new NotSupportedException( String.Format( "Unsupported Style value '{0}'", Style ) );
    }
    
    protected override String AsKey ( )
    {
        String K = ToStringAsValue();
        if ( Style == LuaIntegerStyle.CodePoint )
            K = K.PadLeft(8);
        return K;
    }
    
    public LuaInteger ( Int64 V ) { _Value = V; }
    public LuaInteger ( Int64 V, LuaIntegerStyle S ) :this( V ) { Style = S; }
}

public class LuaReal : LuaNumber
{
    private readonly Double _Value;
    
    public Double Value { get { return _Value; } }
    
    public override String ToStringAsValue ( )
    {
        return _Value.ToString("R");
    }
    
    public LuaReal ( Double V ) { _Value = V; }
}

public class LuaRational : LuaNumber
{
    private readonly Int64 Numerator, Denominator;
    
    public Double Value { get { return (Double)Numerator / (Double)Denominator; } }
    
    public override String ToStringAsValue ( )
    {
        return String.Format( "{0:F1}/{1:F1}", (Double)Numerator, (Double)Denominator );
    }
    
    public LuaRational ( Int64 Num, Int64 Den )
    {
        Numerator = Num;
        Denominator = Den;
    }
}

// TODO: Needs a bit of work on validation and such.
// Identifier falls back to Long when it can't be used, Long falls back to DoubleQuote when it can't be used
public enum LuaStringStyle {
    DoubleQuote, /*SingleQuote,*/ Long, Identifier }
public class LuaString : LuaValue
{
    private static readonly Dictionary<Char,String> Escapes;
    private static readonly Regex PrintableTest, IdentifierTest, LongStringProblemPattern;
    private readonly LuaStringStyle Style = LuaStringStyle.DoubleQuote;
    private readonly String _Value;
    
    public String Value { get { return _Value; } }
    
    public override String ToStringAsValue ( )
    {
        switch ( Style )
        {
            case LuaStringStyle.DoubleQuote :
                return FormatDoubleQuote( Value );
            
            case LuaStringStyle.Long :
            case LuaStringStyle.Identifier :
                return FormatLong( Value );
            
            default :
                throw new NotSupportedException( String.Format( "Unsupported Style value '{0}'", Style ) );
        }
    }
    
    // TODO
    public override String ToStringAsKey ( Int32 Padding )
    {
        switch ( Style )
        {
            case LuaStringStyle.Identifier :
                return Value;
            case LuaStringStyle.Long :
                return String.Concat( "[ ", ToStringAsValue(), " ]" );
            case LuaStringStyle.DoubleQuote :
                return String.Concat( "[", ToStringAsValue(), "]" );
            default :
                throw new NotSupportedException( String.Format( "Unsupported Style value '{0}'", Style ) );
        }
    }
    
    private static String FormatDoubleQuote ( String S )
    {
        StringBuilder Builder = new StringBuilder( );
        Byte[] Bytes = Encoding.UTF8.GetBytes( S );
        for ( UInt16 Idx = 0; Idx < Bytes.Length; Idx++ )
        {
            Byte B = Bytes[ Idx ];
            String Out = null;
            if ( Escapes.TryGetValue( (Char)B, out Out ) )
                Builder.Append( Out );
            else if ( (Byte)' ' <= B && B <= (Byte)'~' ) // Is within ASCII, not otherwise escaped
                Builder.Append( (Char)B );
            else if ( Idx < Bytes.Length-1 && '0' <= Bytes[Idx+1] && Bytes[Idx+1] <= '9' ) // Non-printable, a digit follows this one
                Builder.Append( "\\" + B.ToString( "D3" ) );
            else
                Builder.Append( "\\" + B.ToString( "D" ) );
        }
        return String.Concat( "\"", Builder.ToString(), "\"" );
    }
    
    private static String FormatLong ( String S )
    {
        if ( !IsPrintableAscii(S) )
            throw new ArgumentException();
        MatchCollection Problems = LongStringProblemPattern.Matches( S );
        Int32[] NumEqs = Problems.Cast<Match>()
            .Select<Match,Int32>( (Match) => {return Match.Length-2;} )
            .Distinct()
            .ToArray();
        Array.Sort( NumEqs );
        
        Int32 Counter = 0;
        while ( Counter < NumEqs.Length && Counter == NumEqs[ Counter ] )
            Counter++;
        
        return String.Format( "[{0}[{1}]{0}]", new String( '=', Counter ), S );
    }
    
    // "Printable" does include the space character, in this context
    private static Boolean IsPrintableAscii ( String Input )
    {
        return PrintableTest.IsMatch( Input );
    }
    
    // Does it qualify for Lua's identifier rules?
    private static Boolean CanBeIdentifier ( String Input )
    {
        return IdentifierTest.IsMatch( Input );
    }
    
    static LuaString ( )
    {
        PrintableTest = new Regex( @"^[\x20-\x7E]*$" );
        IdentifierTest = new Regex( @"^[_a-zA-Z][_a-zA-Z0-9]*$" );
        LongStringProblemPattern = new Regex( @"\]=*\]" );
        // The only ones supported are those used by Lua 5.1
        Escapes = new Dictionary<Char,String> {
            { '\u0007', @"\a" },
            { '\b',     @"\b" },
            { '\f',     @"\f" },
            { '\n',     @"\n" },
            { '\r',     @"\r" },
            { '\t',     @"\t" },
            { '\v',     @"\v" },
            { '\\',     @"\\" },
            { '"',     "\\\"" } // Done differently because NP++ doesn't understand @-strings
        };
    }
    
    public LuaString ( String Value ) { _Value = Value; }
    public LuaString ( String Value, LuaStringStyle Style )
        :this( Value ) 
    { 
        if ( Style == LuaStringStyle.Identifier && !CanBeIdentifier( Value ) )
            throw new ArgumentException( String.Format( "String '{0}' is of wrong format to be an identifier.", Value ) );
        if ( Style == LuaStringStyle.Long && !IsPrintableAscii( Value ) )
            throw new ArgumentException( String.Format( "String '{0}' is of wrong format to be a long string.", Value ) );
        this.Style = Style;
    }
}

public class LuaArray : LuaValue
{
    private readonly List<LuaValue> _Values;
    public IList<LuaValue> Values { get { return _Values.AsReadOnly(); } }
    
    public override String ToStringAsValue ( )
    {
        return "{ " + String.Join( ", ", _Values.Select<LuaValue,String>( v => v.ToStringAsValue() ).ToArray() ) + " }";
    }
    
    public LuaArray ( params LuaValue[] vs )
    {
        _Values = new List<LuaValue>( vs );
    }
    
    public LuaArray ( IEnumerable<LuaValue> vs )
    {
        _Values = new List<LuaValue>( vs );
    }
}

public class LuaUString : LuaValue
{
    private readonly LuaArray _Array;
    public IList<LuaValue> Values { get { return _Array.Values; } }
    
    public override String ToStringAsValue ( )
    {
        return "U" + _Array.ToStringAsValue();
    }
    
    public LuaUString ( String s )
    {
        List<LuaValue> Points = new List<LuaValue>();
        for ( Int32 idx = 0; idx < s.Length ; idx++ )
        {
            Int32 CP = Char.ConvertToUtf32( s, idx );
            Points.Add( new LuaInteger( CP, LuaIntegerStyle.Hexadecimal ) );
            if ( Char.IsSurrogatePair( s, idx ) )
                idx++;
        }
        _Array = new LuaArray( Points );
    }
}

// Specialty type, used only for constructing Name_Alias entries for now
// TODO: This whole deal with Name_Alias should be redesigned
public class LuaMixedTable : LuaValue
{
    private readonly List<String> Items;
    
    public override String ToStringAsValue ( )
    {
        return "{ " + String.Join( " ", Items.ToArray() ) + " }";
    }
    
    public void Add ( LuaKV KV )
    {
        Items.Add( KV.ToString() );
    }
    
    public void Add ( LuaValue Val )
    {
        Items.Add( Val.ToStringAsValue() + "," );
    }
    
    public LuaMixedTable ( )
    {
        Items = new List<String>();
    }
}