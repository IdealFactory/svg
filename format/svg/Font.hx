package format.svg;

import openfl.geom.Rectangle;


class Font
{
    public function new() {
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


