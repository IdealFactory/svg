package format.svg;

import openfl.geom.Rectangle;
#if lime
import openfl.text.Font as OpenFLFont;
#end

class Font #if lime extends OpenFLFont #end
{
    public function new(name:String = null) {
        super(name);
        
        id = name;
        fontFace = new FontFace();
        glyphs = new Map<String, Glyph>();
        hkern = [];
        vkern = [];
    }

    public var id:String;
    public var horizOriginX:Float;
    public var horizOriginY:Float;
    public var horizAdvX:Float;
    public var vertOriginX:Float;
    public var vertOriginY:Float;
    public var vertAdvY:Float;

    public var fontFace:FontFace;
    public var missingGlyph:Glyph;
    public var glyphs:Map<String, Glyph>;
    public var hkern:Array<Kern>;
    public var vkern:Array<Kern>;

	public function getSupportedFontChars():Array<String>
    {
        var a = [];
        for (g in glyphs)
        {
            a.push(g.unicode);
        }
        return a;
    }    
}

class FontFace
{
    public function new() { }

    public var fontFamily:String;
    public var fontWeight:Int;
    public var fontStretch:String;
    public var unitsPerEm:Int;
    public var panose1:String;
    public var ascent:Int;
    public var descent:Int;
    public var xHeight:Int;
    public var capHeight:Int;
    public var bbox:Rectangle;
    public var underlineThickness:Float;
    public var underlinePosition:Int;
    public var unicodeRange:String;
}

class Glyph
{
    public function new() {
        segments = [];
    }

    public var name:String;
	public var unicode:String;
	public var path:String;
    public var horizAdvX:Float;
    public var vertOriginX:Float;
    public var vertOriginY:Float;
    public var vertAdvY:Float;
    public var orientation:String;
    public var arabicForm:String;
    public var lang:String;
    public var segments:Array<PathSegment>;

    public function clone() {
        var g = new Glyph();
        g.name = this.name;
        g.unicode = this.unicode;
        g.path = this.path;
        g.horizAdvX = this.horizAdvX;
        g.vertOriginX = this.vertOriginX;
        g.vertOriginY = this.vertOriginY;
        g.vertAdvY = this.vertAdvY;
        g.orientation = this.orientation;
        g.arabicForm = this.arabicForm;
        g.lang = this.lang;
        g.segments = this.segments;
        return g;
    }
}

class Kern
{
    public function new() { }

    public var u1:String;
	public var u2:String;
	public var g1:String;
	public var g2:String;
	public var k:Int;
}


