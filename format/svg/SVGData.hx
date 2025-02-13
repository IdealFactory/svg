package format.svg;

import openfl.geom.Matrix;
import openfl.geom.Transform;
import openfl.geom.Rectangle;
import openfl.display.Bitmap;
import openfl.display.GradientType;
import openfl.display.Graphics;
import openfl.display.SpreadMethod;
import openfl.display.CapsStyle;
import openfl.display.JointStyle;
import openfl.utils.ByteArray;
import openfl.net.URLRequest;
import openfl.net.URLLoader;
import format.svg.Grad;
import format.svg.Group;
import format.svg.FillType;
import format.svg.PathParser;
import format.svg.PathSegment;
import format.svg.Path;
import format.svg.SVGRenderer;
import format.svg.StrokeType;
import format.svg.Text;
import format.svg.Font;
import haxe.io.Bytes;

#if haxe3
import haxe.ds.StringMap;
#else
typedef StringMap<T> = Hash<T>;
#end


class SVGData extends Group {
	
	
	private static inline var SIN45:Float = 0.70710678118654752440084436210485;
	private static inline var TAN22:Float = 0.4142135623730950488016887242097;
	private static var mStyleSplit = ~/;/g;
	private static var mStyleValue = ~/\s*(.*)\s*:\s*(.*)\s*/;
	private static var mTranslateMatch = ~/translate\((.*)[, ](.*)\)/;
	private static var mScaleMatch = ~/scale\((.*)\)/;
	private static var mMatrixMatch = ~/matrix\((.*?)[, ]+(.*?)[, ]+(.*?)[, ]+(.*?)[, ]+(.*?)[, ]+(.*?)\)/;
	private static var mRotationMatch = ~/rotate\(([0-9\.]+)(\s+([0-9\.]+)\s*[, ]\s*([0-9\.]+))?\)/;
	private static var mURLMatch = ~/url\(#(.*)\)/;
	private static var mRGBMatch = ~/rgb\s*\(\s*(\d+)\s*(%)?\s*,\s*(\d+)\s*(%)?\s*,\s*(\d+)\s*(%)?\s*\)/;
	private static var defaultFill = FillSolid(0x000000, 1.0);
	
	public var height (default, null):Float;
	public var width (default, null):Float;

	public var svgFont:Font = null;

	private var mConvertCubics:Bool;
	private var mGrads:GradHash;
	private var mPathParser:PathParser;
	private var baseImageUrl:String;
	
	
	public function new (inXML:Xml, ?inConvertCubics:Bool = false, inBaseImageUrl:String = "") {
		
		super();
		
		var svg = inXML.firstElement();
		
		if (svg == null || (svg.nodeName != "svg" && svg.nodeName != "svg:svg"))
			throw "Not an SVG file (" + (svg==null ? "null" : svg.nodeName) + ")";
		
		mGrads = new GradHash ();
		mPathParser = new PathParser ();
		mConvertCubics = inConvertCubics;
		baseImageUrl = inBaseImageUrl;
		
		width = getFloatStyle("width", svg, null, 0.0);
		height = getFloatStyle("height", svg, null, 0.0);

        var viewBoxX = 0.;
        var viewBoxY = 0.;
        var viewBoxWidth = 0.;
        var viewBoxHeight = 0.;

        if (svg.exists("viewBox")) {

            var vbox = svg.get("viewBox");
            var params = vbox.indexOf(",") != -1 ? vbox.split(",") : vbox.split(" ");
            viewBoxX = trimToFloat(params[0]);
            viewBoxY = trimToFloat(params[1]);
            viewBoxWidth = trimToFloat(params[2]);
            viewBoxHeight = trimToFloat(params[3]);

        }

		if (width == 0 && height == 0) {
            if(viewBoxWidth != 0) width = viewBoxWidth;
            else width = 400;

            if(viewBoxHeight != 0) height = viewBoxHeight;
            else height = 400;

        } else if (width == 0) {
			width = height;
        } else if (height == 0) {
			height = width;
        }

		var viewBox = new Rectangle(0, 0, width, height);

		if (svg.exists("viewBox")) {
			viewBox = new Rectangle(viewBoxX, viewBoxY, viewBoxWidth, viewBoxHeight);
		}

		loadGroup(this, svg, new Matrix (1, 0, 0, 1, -viewBox.x, -viewBox.y), null);
		
	}


	inline function trimToFloat (value:String) {

		return Std.parseFloat( StringTools.trim(value) );

	}
	
	
    // Applies the transformation specified in inTrans to ioMatrix. Returns the new scale
    // value after applying the transformation. 
	private function applyTransform (ioMatrix:Matrix, inTrans:String):Float {
		
		var scale = 1.0;
		
        if (mTranslateMatch.match(inTrans))
		{
			// TODO: Pre-translate
			
			ioMatrix.translate (Std.parseFloat (mTranslateMatch.matched (1)), Std.parseFloat (mTranslateMatch.matched (2)));
			
		} else if (mScaleMatch.match (inTrans)) {
			
			// TODO: Pre-scale
			var s = Std.parseFloat (mScaleMatch.matched (1));
			ioMatrix.scale (s, s);
			scale = s;
			
		} else if (mMatrixMatch.match (inTrans)) {
			
			var m = new Matrix (
				Std.parseFloat (mMatrixMatch.matched (1)),
				Std.parseFloat (mMatrixMatch.matched (2)),
				Std.parseFloat (mMatrixMatch.matched (3)),
				Std.parseFloat (mMatrixMatch.matched (4)),
				Std.parseFloat (mMatrixMatch.matched (5)),
				Std.parseFloat (mMatrixMatch.matched (6))
			);
			
			m.concat (ioMatrix);
			
			ioMatrix.a = m.a;
			ioMatrix.b = m.b;
			ioMatrix.c = m.c;
			ioMatrix.d = m.d;
			ioMatrix.tx = m.tx;
			ioMatrix.ty = m.ty;
			
			scale = Math.sqrt (ioMatrix.a * ioMatrix.a + ioMatrix.c * ioMatrix.c);
        } else if (mRotationMatch.match (inTrans)) {
            
            var degrees = Std.parseFloat (mRotationMatch.matched (1));
            
            var rotationX = Std.parseFloat (mRotationMatch.matched (2));
            if (Math.isNaN(rotationX)) {
                rotationX = 0;
            }	            
            var rotationY = Std.parseFloat (mRotationMatch.matched (3));
            if (Math.isNaN(rotationY)) {
                rotationY = 0;
            }
            
            var radians = degrees * Math.PI / 180;	
            
            ioMatrix.translate (-rotationX, -rotationY);
            ioMatrix.rotate(radians);
            ioMatrix.translate (rotationX, rotationY);
		} else { 
			
			trace("Warning, unknown transform:" + inTrans);
			
		}
		
		return scale;
		
	}
	
	
	private function dumpGroup (g:Group, indent:String) {
		
		trace (indent + "Group:" + g.name);
		indent += "  ";
		
		for (e in g.children) {
			
			switch (e) {
				
				case DisplayPath (path): trace (indent + "Path" + "  " + path.matrix);
				case DisplayGroup (group): dumpGroup (group, indent+"   ");
				case DisplayText (text): trace (indent + "Text " + text.text);
				case DisplayImage (image): trace (indent + "Image " + image.href);
				
			}
			
		}
		
	}
	
	
	private function getColorStyle (inKey:String, inNode:Xml, inStyles:StringMap <String>, inDefault:Int) {
		
		var s = getStyle (inKey, inNode, inStyles, "");
		
		if (s == "") {
			
			return inDefault;
			
		}
		
		if (s.charAt (0) == '#') {

			return parseHex(s.substr(1));
			
		}
				
		if (mRGBMatch.match (s)) {
			
			return parseRGBMatch(mRGBMatch);
			
		}

		if (SVGColor.getColor(s) != null) {

			return SVGColor.getColor(s);

		}
		
		return Std.parseInt (s);
		
	}
	
	
	private function getFillStyle (inKey:String, inNode:Xml, inStyles:StringMap<String>) {
		
		var s = getStyle (inKey, inNode, inStyles, "");
		
		if (s == "") {
			
			return defaultFill;
			
		}
		
		if (s.charAt (0) == '#') {
			
			return FillSolid (parseHex(s.substr(1)), 1.0);
			
		}

		if (mRGBMatch.match (s)) {
			
			return FillSolid ( parseRGBMatch(mRGBMatch), 1.0 );
			
		}
		
		if (s == "none") {
			
			return FillNone;
			
		}
		
		if (mURLMatch.match (s)) {
			
			var url = mURLMatch.matched (1);
			
			if (mGrads.exists (url)) {
				
				return FillGrad(mGrads.get(url));
				
			}
			
			throw ("Unknown url:" + url);
			
		}
		
		throw ("Unknown fill string:" + s);
		
		return FillNone;
		
	}
	
	
	private function getString (inXML:Xml, inName:String, inDef:String = ""):String {
		
		if (inXML.exists (inName))
			return inXML.get (inName);
		
		return inDef;
		
	}

	private function getInt (inXML:Xml, inName:String, inDef:Int = 0):Int {
		
		if (inXML.exists (inName))
			return Std.parseInt (inXML.get (inName));
		
		return inDef;
		
	}
	
	
	private function getFloat (inXML:Xml, inName:String, inDef:Float = 0.0, percentRange:Float = 0.0):Float {
		
		if (inXML.exists (inName)) {
			var val = inXML.get (inName);
			if (val.indexOf("%")==val.length-1) {
				var pcntVal = Std.parseFloat (val) * percentRange / 100;
				return pcntVal;
			}
			return Std.parseFloat (val);
		}
		return inDef;
		
	}
	

	private function getPercent (inXML:Xml, inName:String, inDef:Float = -1):Float {
		
		if (inXML.exists (inName)) {
			var val = inXML.get (inName);
			if (val.indexOf("%")==val.length-1) {
				var pcntVal = Math.max(0, Math.min(1, Std.parseFloat (val) / 100));
				return pcntVal;
			}
			return inDef;
		}
		return inDef;
		
	}
	

	private function getRect (inXML:Xml, inName:String, inDef:Rectangle = null):Rectangle {
		
		if (inXML.exists (inName)) {
			var r = inXML.get (inName).split(' ');

			return new Rectangle( Std.parseFloat(r[0]),  Std.parseFloat(r[1]), Std.parseFloat(r[2]), Std.parseFloat(r[3]) );
		}
		return inDef!=null ? inDef : new Rectangle();
		
	}
	
	
	private function getFloatStyle (inKey:String, inNode:Xml, inStyles:StringMap<String>, inDefault:Float) {
		
		var s = getStyle (inKey, inNode, inStyles, "");
		
		if (s == "") {
			
			return inDefault;
		
		}
		
		return Std.parseFloat (s);
		
	}
	
	
	private function getStyleAndConvert<T>(inKey:String, inNode:Xml, inStyles:StringMap<String>, inDefault:T, inConvert:StringMap<T>) : T {
		
		var s = getStyle (inKey, inNode, inStyles, "");
		
		if (s == "" || !inConvert.exists(s)) {
			
			return inDefault;
		
		}
		
		return inConvert.get(s);
		
	}


	private function getStrokeStyle (inKey:String, inNode:Xml, inStyles:StringMap <String>, inDefault:StrokeType = StrokeType.StrokeNone) {
		
		var s = getStyle (inKey, inNode, inStyles, "");
		
		if (s == "") {
			
			return inDefault;
			
		}


		if (mRGBMatch.match (s)) {
			
			return StrokeSolid( parseRGBMatch(mRGBMatch), 1.0 );
			
		}
		
		if (s == "none") {
			
			return StrokeNone;
			
		}
		
		if (s.charAt (0) == '#') {
			
			return StrokeSolid( parseHex(s.substr(1)), 1.0 );
			
		}

		if (mURLMatch.match (s)) {
			
			var url = mURLMatch.matched (1);
			
			if (mGrads.exists (url)) {
				
				return StrokeGrad(mGrads.get(url));
				
			}
			
			throw ("Unknown url:" + url);
			
		}

		return StrokeSolid( Std.parseInt (s), 1.0 );
		
	}
	
	
	private function getStyle (inKey:String, inNode:Xml, inStyles:StringMap <String>, inDefault:String) {
		
		if (inNode != null && inNode.exists (inKey)) {
			
			return inNode.get (inKey);
			
		}
		
		if (inStyles != null && inStyles.exists (inKey)) {
			
			return inStyles.get (inKey);
			
		}
		
		return inDefault;
		
	}
	
	
	private function getStyles (inNode:Xml, inPrevStyles:StringMap<String>):StringMap <String> {
		
		if (!inNode.exists ("style"))
			return inPrevStyles;

		var styles = new StringMap <String> ();
		
		if (inPrevStyles != null) {
			
			for (s in inPrevStyles.keys ()) {
				
				styles.set (s, inPrevStyles.get (s));
			
			}
			
		}

		var style = inNode.get ("style");
		var strings = mStyleSplit.split (style);
		
		for (s in strings) {
		
			if (mStyleValue.match (s)) {
				
				styles.set (mStyleValue.matched (1), mStyleValue.matched (2));
				
			}
			
		}
		
		return styles;
		
	}
	
	
	private function loadDefs (inXML:Xml) {
		
		// Two passes - to allow forward xlinks
		
		for (pass in 0...2) {
			
			for (def in inXML.elements ()) {
				
				var name = def.nodeName;
				
				if (name.substr (0, 4) == "svg:") {
					
					name = name.substr (4);
					
				}
				
				if (name == "linearGradient") {
					
					loadGradient (def, GradientType.LINEAR, pass == 1);
				
				} else if (name == "radialGradient") {
					
					loadGradient (def, GradientType.RADIAL, pass == 1);
					
				}

				if (pass == 0) {
					if (name == "font") {
						
						loadFont (def);
					
					}
				}
			}
			
		}
		
	}
	
	
	private function loadGradient (inGrad:Xml, inType:GradientType, inCrossLink:Bool) {
		
		var name = inGrad.get ("id");
		var grad = new Grad (inType);
		
		if (inCrossLink && inGrad.exists("xlink:href")) {
			
			var xlink = inGrad.get ("xlink:href");
			
			if (xlink.charAt(0) != "#")
				throw ("xlink - unkown syntax : " + xlink);
			
			var base = mGrads.get (xlink.substr (1));
			
			if (base != null) {
				
				grad.colors = base.colors;
				grad.alphas = base.alphas;
				grad.ratios = base.ratios;
				grad.gradMatrix = base.gradMatrix.clone ();
				grad.spread = base.spread;
				grad.interp = base.interp;
				grad.radius = base.radius;
				
			} else {
				
				throw ("Unknown xlink : " + xlink);
				
			}
			
		}

		if (inType == GradientType.LINEAR) {

			grad.x1 = getFloat (inGrad, "x1", 0, width);
			grad.y1 = getFloat (inGrad, "y1", 0, height);
			grad.x2 = getFloat (inGrad, "x2", width, width);
			grad.y2 = getFloat (inGrad, "y2", height, height);
			grad.x1Ratio = getPercent (inGrad, "x1", -1);
			grad.y1Ratio = getPercent (inGrad, "y1", -1);
			grad.x2Ratio = getPercent (inGrad, "x2", -1);
			grad.y2Ratio = getPercent (inGrad, "y2", -1);

		} else {
			
			grad.x1 = getFloat (inGrad, "cx", width * 0.5, width);
			grad.y1 = getFloat (inGrad, "cy", height * 0.5, height);
			grad.x2 = getFloat (inGrad, "fx", grad.x1, width);
			grad.y2 = getFloat (inGrad, "fy", grad.y1, height);
			grad.x1Ratio = getPercent (inGrad, "x1", -1);
			grad.y1Ratio = getPercent (inGrad, "y1", -1);
			grad.x2Ratio = getPercent (inGrad, "x2", -1);
			grad.y2Ratio = getPercent (inGrad, "y2", -1);
			
		}

		grad.radius = getFloat (inGrad, "r");
		
		if (inGrad.exists ("gradientTransform")) {
			
			applyTransform (grad.gradMatrix, inGrad.get ("gradientTransform"));
			
		}
		
		// todo - grad.spread = base.spread;

		for (stop in inGrad.elements ()) {
			
			var styles = getStyles (stop, null);
			
			grad.colors.push (getColorStyle ("stop-color", stop, styles, 0x000000));
			grad.alphas.push (getFloatStyle ("stop-opacity", stop, styles, 1.0));
			grad.ratios.push (Std.int (Std.parseFloat (stop.get ("offset")) * 255.0));
			
		}
		
		mGrads.set (name, grad);
		
	}
	
	
	public function loadGroup (g:Group, inG:Xml, matrix:Matrix, inStyles:StringMap <String>):Group {
		
		if (inG.exists ("transform")) {
			
			matrix = matrix.clone ();
			applyTransform (matrix, inG.get ("transform"));
			
		}
		
		if (inG.exists ("inkscape:label")) {
			
			g.name = inG.get ("inkscape:label");
			
		} else if (inG.exists ("id")) {
			
			g.name = inG.get ("id");
			
		}
		
		var styles = getStyles (inG, inStyles);

		/*
		supports eg:
		<g>
			<g opacity="0.5">
				<path ... />
				<polygon ... />
			</g>
		</g>
		*/
		if (inG.exists("opacity")) {

			var opacity = inG.get("opacity");

			if (styles == null)
				styles = new StringMap<String>();

			if (styles.exists("opacity"))
				opacity = Std.string( Std.parseFloat(opacity) * Std.parseFloat(styles.get("opacity")) );
			
			styles.set("opacity", opacity);

		}

		for (el in inG.elements ()) {
			
			var name = el.nodeName;
			
			if (name.substr (0, 4) == "svg:") {
				
				name = name.substr(4);
				
			}

			if (el.exists("display") && el.get("display") == "none") continue;

			if (name == "defs") {
				
				loadDefs (el);
				
			} else if (name == "g") {
				
				if (!(el.exists("display") && el.get("display") == "none")) {
				
					g.children.push (DisplayGroup (loadGroup (new Group (), el, matrix, styles)));
					
				}
				
			} else if (name == "path" || name == "line" || name == "polyline") {
				
				g.children.push (DisplayPath (loadPath (el, matrix, styles, false, false)));
				
			} else if (name == "rect") {
				
				g.children.push (DisplayPath (loadPath (el, matrix, styles, true, false)));
				
			} else if (name == "polygon") {
				
				g.children.push (DisplayPath (loadPath (el, matrix, styles, false, false)));
				
			} else if (name == "ellipse") {
				
				g.children.push (DisplayPath (loadPath (el, matrix, styles, false, true)));
				
			} else if (name == "circle") {
				
				g.children.push (DisplayPath (loadPath (el, matrix, styles, false, true, true)));
				
			} else if (name == "image") {
				
				g.children.push (DisplayImage (loadImage (el, matrix, styles)));

			} else if (name == "text") {
				
				g.children.push (DisplayText (loadText (el, matrix, styles)));
				
			} else if (name == "linearGradient") {
				
				loadGradient (el, GradientType.LINEAR, true);
				
			} else if (name == "radialGradient") {
				
				loadGradient (el, GradientType.RADIAL, true);
				
			} else if (name == "title") {

				g.title = (el.firstChild() != null) ? Std.string(el.firstChild()) : '';

			}  else {
				
				// throw("Unknown child : " + el.nodeName );
				
			}
			
		}
		
		return g;
		
	}
	
	
	private function loadFont (inFont:Xml) {
		var name = getString(inFont, "id");
		var font = new Font(name);
		font.horizOriginX = getFloat(inFont, "horiz-origin-x", 0);
		font.horizOriginY = getFloat(inFont, "horiz-origin-y", 0);
		font.horizAdvX = getFloat(inFont, "horiz-adv-x", 0);
		font.vertOriginX = getFloat(inFont, "vert-origin-x", font.horizAdvX / 2);
		font.vertOriginY = getFloat(inFont, "vert-origin-y", 0);
		font.vertAdvY = getFloat(inFont, "vert-adv-y", 0);
		font.glyphs = [];
		font.hkern = [];
		font.vkern = [];

		for (el in inFont.elements ()) {
				
			var name = el.nodeName;
			
			switch (name) {
				case "font-face":
					var ff = font.fontFace;
					ff.fontFamily = getString(el, "font-family");
					ff.fontWeight = getInt(el, "font-weight", 400);
					ff.fontStretch = getString(el, "font-stretch");
					ff.unitsPerEm = getInt(el, "units-per-em", 1000);
					ff.panose1 = getString(el, "panose-1");
					ff.ascent = getInt(el, "ascent", 800);
					ff.descent = getInt(el, "descent", -200);
					ff.xHeight = getInt(el, "x-height", 400);
					ff.capHeight = getInt(el, "cap-height", 700);
					ff.bbox = getRect(el, "bbox");
					ff.underlineThickness = getInt(el, "underline-thickness", 20);
					ff.underlinePosition = getInt(el, "underline-position", -210);
					ff.unicodeRange = getString(el, "unicode-range","U+0-10FFFF");
				case "missing-glyph":
					var glyph = new Glyph();
					glyph.name = "missing-glyph";
					glyph.path = getString(el, "d");
					glyph.horizAdvX = getFloat(el, "horiz-adv-x", font.horizAdvX);
					glyph.vertOriginX = getFloat(el, "vert-origin-x", font.vertOriginX);
					glyph.vertOriginY = getFloat(el, "vert-origin-y", font.vertOriginY);
					glyph.vertAdvY = getFloat(el, "vert-adv-y", font.vertAdvY);
					for (segment in mPathParser.parse (glyph.path, mConvertCubics)) {
						glyph.segments.push (segment);
					}
					font.missingGlyph = glyph;			
				case "glyph":
					var glyph = new Glyph();
					glyph.name = getString(el, "glyph-name");
					glyph.unicode = getString(el, "unicode");
					glyph.path = getString(el, "d");
					glyph.horizAdvX = getFloat(el, "horiz-adv-x", font.horizAdvX);
					glyph.vertOriginX = getFloat(el, "vert-origin-x", font.vertOriginX);
					glyph.vertOriginY = getFloat(el, "vert-origin-y", font.vertOriginY);
					glyph.vertAdvY = getFloat(el, "vert-adv-y", font.vertAdvY);
					glyph.orientation = getString(el, "orientation");
					glyph.arabicForm = getString(el, "arabic-form");
					glyph.lang = getString(el, "lang");
					for (segment in mPathParser.parse (glyph.path, mConvertCubics)) {
						glyph.segments.push (segment);
					}
					font.glyphs[glyph.unicode] = glyph;
				case "hkern":
					var kern = new Kern();
					kern.u1 = getString(el, "u1");
					kern.u2 = getString(el, "u2");
					kern.g1 = getString(el, "g1");
					kern.g2 = getString(el, "g2");
					kern.k = getInt(el, "k");
					font.hkern.push( kern );
				case "vkern":
					var kern = new Kern();
					kern.u1 = getString(el, "u1");
					kern.u2 = getString(el, "u2");
					kern.g1 = getString(el, "g1");
					kern.g2 = getString(el, "g2");
					kern.k = getInt(el, "k");
					font.vkern.push( kern );
				default:
					// Unknown element
			}
		}
		font.toLime();

		svgFont = font;
	}


	public function loadPath (inPath:Xml, matrix:Matrix, inStyles:StringMap<String>, inIsRect:Bool, inIsEllipse:Bool, inIsCircle:Bool=false):Path {
		
		if (inPath.exists ("transform")) {
			
			matrix = matrix.clone ();
			applyTransform (matrix, inPath.get ("transform"));
			
		}
		
		var styles = getStyles (inPath, inStyles);
		var name = inPath.exists ("id") ? inPath.get ("id") : "";
		var path = new Path ();
		
		path.fill = getFillStyle ("fill", inPath, styles);
		path.alpha = getFloatStyle ("opacity", inPath, styles, 1.0);
		path.fill_alpha = getFloatStyle ("fill-opacity", inPath, styles, 1.0);
		path.stroke_alpha = getFloatStyle ("stroke-opacity", inPath, styles, 1.0);
		path.stroke_colour = getStrokeStyle ("stroke", inPath, styles, null);
		path.stroke_width = getFloatStyle ("stroke-width", inPath, styles, 1.0);
		path.stroke_style = getStyleAndConvert ("paint-order", inPath, styles, StrokeStyle.BOTH, 
			["stroke fill" => StrokeStyle.OUTSIDE, "fill stroke" => StrokeStyle.BOTH]);
		path.stroke_caps = getStyleAndConvert ("stroke-linecap", inPath, styles, CapsStyle.NONE, 
			["round" => CapsStyle.ROUND, "square" => CapsStyle.SQUARE, "butt" => CapsStyle.NONE]);
		path.joint_style = getStyleAndConvert ("stroke-linejoin", inPath, styles, JointStyle.MITER, 
			["bevel" => JointStyle.BEVEL, "round" => JointStyle.ROUND, "miter" => JointStyle.MITER]);
		path.miter_limit = getFloatStyle ("stroke-miterlimit", inPath, styles, 3.0);
		path.segments = [];
		path.matrix = matrix;
		path.name = name;

		if (inIsRect) {
			
			var x = inPath.exists ("x") ? Std.parseFloat (inPath.get ("x")) : 0;
			var y = inPath.exists ("y") ? Std.parseFloat (inPath.get ("y")) : 0;
			var w = Std.parseFloat (inPath.get ("width"));
			var h = Std.parseFloat (inPath.get ("height"));
			var rx = inPath.exists ("rx") ? Std.parseFloat (inPath.get ("rx")) : 0.0;
			var ry = inPath.exists ("ry") ? Std.parseFloat (inPath.get ("ry")) : 0.0;
			
			if (rx == 0 || ry == 0) {
				
				path.segments.push (new MoveSegment (x , y));
				path.segments.push (new DrawSegment (x + w, y));
				path.segments.push (new DrawSegment (x + w, y + h));
				path.segments.push (new DrawSegment (x, y + h));
				path.segments.push (new DrawSegment (x, y));
				
			} else {
				
				path.segments.push (new MoveSegment (x, y + ry));
				
				// top-left
				path.segments.push (new QuadraticSegment (x, y, x + rx, y));
				path.segments.push (new DrawSegment (x + w - rx, y));
				
				// top-right
				path.segments.push (new QuadraticSegment (x + w, y, x + w, y + rx));
				path.segments.push (new DrawSegment (x + w, y + h - ry));
				
				// bottom-right
				path.segments.push (new QuadraticSegment (x + w, y + h, x + w - rx, y + h));
				path.segments.push (new DrawSegment (x + rx, y + h));
				
				// bottom-left
				path.segments.push (new QuadraticSegment (x, y + h, x, y + h - ry));
				path.segments.push (new DrawSegment (x, y + ry));
				
			}
			
		} else if (inIsEllipse) {
			
			var x = inPath.exists ("cx") ? Std.parseFloat (inPath.get ("cx")) : 0;
			var y = inPath.exists ("cy") ? Std.parseFloat (inPath.get ("cy")) : 0;
			var r = inIsCircle && inPath.exists ("r") ? Std.parseFloat (inPath.get ("r")) : 0.0; 
			var w = inIsCircle ? r : inPath.exists ("rx") ? Std.parseFloat (inPath.get ("rx")) : 0.0;
			var w_ = w * SIN45;
			var cw_ = w * TAN22;
			var h = inIsCircle ? r : inPath.exists ("ry") ? Std.parseFloat (inPath.get ("ry")) : 0.0;
			var h_ = h * SIN45;
			var ch_ = h * TAN22;
			
			path.segments.push (new MoveSegment (x + w, y));
			path.segments.push (new QuadraticSegment (x + w, y + ch_, x + w_, y + h_));
			path.segments.push (new QuadraticSegment (x + cw_, y + h, x, y + h));
			path.segments.push (new QuadraticSegment (x - cw_, y + h, x - w_, y + h_));
			path.segments.push (new QuadraticSegment (x - w, y + ch_, x - w, y));
			path.segments.push (new QuadraticSegment (x - w, y - ch_, x - w_, y - h_));
			path.segments.push (new QuadraticSegment (x - cw_, y - h, x, y - h));
			path.segments.push (new QuadraticSegment (x + cw_, y - h, x + w_, y - h_));
			path.segments.push (new QuadraticSegment (x + w, y - ch_, x + w, y));
			
		} else {
			
			var d = inPath.exists ("points") ? ("M" + inPath.get ("points") + "z") : 
					inPath.exists ("x1") ? ("M" + inPath.get ("x1") + "," + inPath.get ("y1") + " " + inPath.get ("x2") + "," + inPath.get ("y2") + "z") : 
					inPath.get ("d");
			
			for (segment in mPathParser.parse (d, mConvertCubics)) {
				
				path.segments.push (segment);
				
			}
			
		}

		return path;
		
	}
	
	
	public function loadImage (inImage:Xml, matrix:Matrix, inStyles:StringMap <String>):Image {
		
		if (inImage.exists ("transform")) {
			
			matrix = matrix.clone ();
			applyTransform (matrix, inImage.get ("transform"));
			
		}
		
		var styles = getStyles (inImage, inStyles);
		var image = new Image ();
		
		image.href = inImage.exists ("xlink:href") ? inImage.get ("xlink:href") : "";
		if (image.href.indexOf("http://") == -1 && image.href.indexOf("https://") == -1) {
			image.uri = image.href;
			image.href = baseImageUrl + image.href;
		}

		if(inImage.firstElement() != null && inImage.firstElement().nodeName == 'title') {
			image.title = (inImage.firstElement().firstChild() != null) ? Std.string(inImage.firstElement().firstChild()) : '';
		}

		image.bitmap = new Bitmap();
		image.bitmap.smoothing = true;
		image.name = image.bitmap.name = inImage.exists ("id") ? inImage.get ("id") : image.uri;
		image.x = image.bitmap.x = getFloat (inImage, "x", 0.0);
		image.y = image.bitmap.y = getFloat (inImage, "y", 0.0);
		image.width = image.bitmap.width = getFloat (inImage, "width", 0.0);
		image.height = image.bitmap.height = getFloat (inImage, "height", 0.0);
		image.visible = getStyle( "display", inImage, styles, "block" ) != "none";
		image.matrix = matrix;

		return image;
		
	}

	public function loadText (inText:Xml, matrix:Matrix, inStyles:StringMap <String>):Text {
		
		if (inText.exists ("transform")) {
			
			matrix = matrix.clone ();
			applyTransform (matrix, inText.get ("transform"));
			
		}
		
		var styles = getStyles (inText, inStyles);
		var text = new Text ();
		
		text.matrix = matrix;
		text.name = inText.exists ("id") ? inText.get ("id") : "";
		text.x = getFloat (inText, "x", 0.0);
		text.y = getFloat (inText, "y", 0.0);
		text.fill = getFillStyle ("fill", inText, styles);
		text.fill_alpha = getFloatStyle ("fill-opacity", inText, styles, 1.0);
		text.stroke_alpha = getFloatStyle ("stroke-opacity", inText, styles, 1.0);
		text.stroke_colour = getStrokeStyle ("stroke", inText, styles, StrokeType.StrokeNone);
		text.stroke_width = getFloatStyle ("stroke-width", inText, styles, 1.0);
		text.font_family = getStyle ("font-family", inText, styles, "");
		text.font_size = getFloatStyle ("font-size", inText, styles, 12);
		text.letter_spacing = getFloatStyle ("letter-spacing", inText, styles, 0);
		text.kerning = getFloatStyle ("kerning", inText, styles, 0);
		text.text_align = getStyle ("text-align", inText, styles, "start");

		var string = "";
		
		for (el in inText.elements ()) {
			
			string += el.toString();
			
		}
		
		//trace(string);
		text.text = string;
		return text;
		
	}

	private static inline function parseHex(hex:String):Int
	{
		// Support 3-character hex color shorthand
		//  e.g. #RGB -> #RRGGBB
		if (hex.length == 3) {
			hex = hex.substr(0,1) + hex.substr(0,1) +
			      hex.substr(1,1) + hex.substr(1,1) +
			      hex.substr(2,1) + hex.substr(2,1);
		}
    
		return Std.parseInt ("0x" + hex);
	}

	private static inline function parseRGBMatch(rgbMatch:EReg):Int
	{
			// CSS2 rgb color definition, matches 0-255 or 0-100%
			// e.g. rgb(255,127,0) == rgb(100%,50%,0)

			inline function range(val:Float):Int {
				// constrain to Int 0-255
				if (val < 0) { val = 0; }
				if (val > 255) { val = 255; }
				return Std.int( val );
			}

			var r = Std.parseFloat(rgbMatch.matched (1));
			if (rgbMatch.matched(2)=='%') { r = r * 255 / 100; }

			var g = Std.parseFloat(rgbMatch.matched (3));
			if (rgbMatch.matched(4)=='%') { g = g * 255 / 100; }

			var b = Std.parseFloat(rgbMatch.matched (5));
			if (rgbMatch.matched(6)=='%') { b = b * 255 / 100; }

			return ( range(r)<<16 ) | ( range(g)<<8 ) | range(b);
	}
}

class SVGColor {
	static var inst:SVGColor;
	var colors = new Map<String,UInt>();
	public function new() {
		colors['black'] = 0x000000;
		colors['navy'] = 0x000080;
		colors['darkblue'] = 0x00008B;
		colors['mediumblue'] = 0x0000CD;
		colors['blue'] = 0x0000FF;
		colors['darkgreen'] = 0x006400;
		colors['green'] = 0x008000;
		colors['teal'] = 0x008080;
		colors['darkcyan'] = 0x008B8B;
		colors['deepskyblue'] = 0x00BFFF;
		colors['darkturquoise'] = 0x00CED1;
		colors['mediumspringgreen'] = 0x00FA9A;
		colors['lime'] = 0x00FF00;
		colors['springgreen'] = 0x00FF7F;
		colors['cyan'] = 0x00FFFF;
		colors['aqua'] = 0x00FFFF;
		colors['midnightblue'] = 0x191970;
		colors['dodgerblue'] = 0x1E90FF;
		colors['lightseagreen'] = 0x20B2AA;
		colors['forestgreen'] = 0x228B22;
		colors['seagreen'] = 0x2E8B57;
		colors['darkslategray'] = 0x2F4F4F;
		colors['darkslategrey'] = 0x2F4F4F;
		colors['limegreen'] = 0x32CD32;
		colors['mediumseagreen'] = 0x3CB371;
		colors['turquoise'] = 0x40E0D0;
		colors['royalblue'] = 0x4169E1;
		colors['steelblue'] = 0x4682B4;
		colors['darkslateblue'] = 0x483D8B;
		colors['mediumturquoise'] = 0x48D1CC;
		colors['indigo'] = 0x4B0082;
		colors['darkolivegreen'] = 0x556B2F;
		colors['cadetblue'] = 0x5F9EA0;
		colors['cornflowerblue'] = 0x6495ED;
		colors['mediumaquamarine'] = 0x66CDAA;
		colors['dimgrey'] = 0x696969;
		colors['dimgray'] = 0x696969;
		colors['slateblue'] = 0x6A5ACD;
		colors['olivedrab'] = 0x6B8E23;
		colors['slategrey'] = 0x708090;
		colors['slategray'] = 0x708090;
		colors['lightslategray'] = 0x778899;
		colors['lightslategrey'] = 0x778899;
		colors['mediumslateblue'] = 0x7B68EE;
		colors['lawngreen'] = 0x7CFC00;
		colors['chartreuse'] = 0x7FFF00;
		colors['aquamarine'] = 0x7FFFD4;
		colors['maroon'] = 0x800000;
		colors['purple'] = 0x800080;
		colors['olive'] = 0x808000;
		colors['gray'] = 0x808080;
		colors['grey'] = 0x808080;
		colors['skyblue'] = 0x87CEEB;
		colors['lightskyblue'] = 0x87CEFA;
		colors['blueviolet'] = 0x8A2BE2;
		colors['darkred'] = 0x8B0000;
		colors['darkmagenta'] = 0x8B008B;
		colors['saddlebrown'] = 0x8B4513;
		colors['darkseagreen'] = 0x8FBC8F;
		colors['lightgreen'] = 0x90EE90;
		colors['mediumpurple'] = 0x9370DB;
		colors['darkviolet'] = 0x9400D3;
		colors['palegreen'] = 0x98FB98;
		colors['darkorchid'] = 0x9932CC;
		colors['yellowgreen'] = 0x9ACD32;
		colors['sienna'] = 0xA0522D;
		colors['brown'] = 0xA52A2A;
		colors['darkgray'] = 0xA9A9A9;
		colors['darkgrey'] = 0xA9A9A9;
		colors['lightblue'] = 0xADD8E6;
		colors['greenyellow'] = 0xADFF2F;
		colors['paleturquoise'] = 0xAFEEEE;
		colors['lightsteelblue'] = 0xB0C4DE;
		colors['powderblue'] = 0xB0E0E6;
		colors['firebrick'] = 0xB22222;
		colors['darkgoldenrod'] = 0xB8860B;
		colors['mediumorchid'] = 0xBA55D3;
		colors['rosybrown'] = 0xBC8F8F;
		colors['darkkhaki'] = 0xBDB76B;
		colors['silver'] = 0xC0C0C0;
		colors['mediumvioletred'] = 0xC71585;
		colors['indianred'] = 0xCD5C5C;
		colors['peru'] = 0xCD853F;
		colors['chocolate'] = 0xD2691E;
		colors['tan'] = 0xD2B48C;
		colors['lightgray'] = 0xD3D3D3;
		colors['lightgrey'] = 0xD3D3D3;
		colors['thistle'] = 0xD8BFD8;
		colors['orchid'] = 0xDA70D6;
		colors['goldenrod'] = 0xDAA520;
		colors['palevioletred'] = 0xDB7093;
		colors['crimson'] = 0xDC143C;
		colors['gainsboro'] = 0xDCDCDC;
		colors['plum'] = 0xDDA0DD;
		colors['burlywood'] = 0xDEB887;
		colors['lightcyan'] = 0xE0FFFF;
		colors['lavender'] = 0xE6E6FA;
		colors['darksalmon'] = 0xE9967A;
		colors['violet'] = 0xEE82EE;
		colors['palegoldenrod'] = 0xEEE8AA;
		colors['lightcoral'] = 0xF08080;
		colors['khaki'] = 0xF0E68C;
		colors['aliceblue'] = 0xF0F8FF;
		colors['honeydew'] = 0xF0FFF0;
		colors['azure'] = 0xF0FFFF;
		colors['sandybrown'] = 0xF4A460;
		colors['wheat'] = 0xF5DEB3;
		colors['beige'] = 0xF5F5DC;
		colors['whitesmoke'] = 0xF5F5F5;
		colors['mintcream'] = 0xF5FFFA;
		colors['ghostwhite'] = 0xF8F8FF;
		colors['salmon'] = 0xFA8072;
		colors['antiquewhite'] = 0xFAEBD7;
		colors['linen'] = 0xFAF0E6;
		colors['lightgoldenrodyellow'] = 0xFAFAD2;
		colors['oldlace'] = 0xFDF5E6;
		colors['red'] = 0xFF0000;
		colors['fuchsia'] = 0xFF00FF;
		colors['magenta'] = 0xFF00FF;
		colors['deeppink'] = 0xFF1493;
		colors['orangered'] = 0xFF4500;
		colors['tomato'] = 0xFF6347;
		colors['hotpink'] = 0xFF69B4;
		colors['coral'] = 0xFF7F50;
		colors['darkorange'] = 0xFF8C00;
		colors['lightsalmon'] = 0xFFA07A;
		colors['orange'] = 0xFFA500;
		colors['lightpink'] = 0xFFB6C1;
		colors['pink'] = 0xFFC0CB;
		colors['gold'] = 0xFFD700;
		colors['peachpuff'] = 0xFFDAB9;
		colors['navajowhite'] = 0xFFDEAD;
		colors['moccasin'] = 0xFFE4B5;
		colors['bisque'] = 0xFFE4C4;
		colors['mistyrose'] = 0xFFE4E1;
		colors['blanchedalmond'] = 0xFFEBCD;
		colors['papayawhip'] = 0xFFEFD5;
		colors['lavenderblush'] = 0xFFF0F5;
		colors['seashell'] = 0xFFF5EE;
		colors['cornsilk'] = 0xFFF8DC;
		colors['lemonchiffon'] = 0xFFFACD;
		colors['floralwhite'] = 0xFFFAF0;
		colors['snow'] = 0xFFFAFA;
		colors['yellow'] = 0xFFFF00;
		colors['lightyellow'] = 0xFFFFE0;
		colors['ivory'] = 0xFFFFF0;
		colors['white'] = 0xFFFFFF;
	}

	public static function getColor(name:String):Null<UInt> {
		if (inst==null) inst = new SVGColor();
		if (inst.colors.exists(name)) return inst.colors[name];
		return null;
	}
}