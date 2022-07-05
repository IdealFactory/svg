package format.svg;

import format.svg.PathParser;
import format.svg.PathSegment;

import openfl.geom.Matrix;
import openfl.geom.Rectangle;
import openfl.display.Graphics;

import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.display.DisplayObject;
import openfl.display.DisplayObjectContainer;
import openfl.display.GradientType;
import openfl.display.SpreadMethod;
import openfl.display.InterpolationMethod;
import openfl.display.CapsStyle;
import openfl.display.JointStyle;
import openfl.display.LineScaleMode;

import format.svg.Grad;
import format.svg.Group;
import format.svg.FillType;
import format.svg.StrokeStyle;
import format.gfx.Gfx;
import openfl.geom.Rectangle;


typedef GroupPath = Array<String>;
typedef ObjectFilter = String->GroupPath->Bool;

class SVGRenderer
{
    public static var SQRT2:Float = Math.sqrt(2);
    public var width(default,null):Float;
    public var height(default,null):Float;
    public var baseImagePath:String = "";
    public var imageDependencies:Map<String, BitmapData>;
	  public var loadImageCallback:Image->Void;

    var mSvg:SVGData;
    var mRoot:Group;
    var mGfx : Gfx;
    var mMatrix : Matrix;
    var mScaleRect:Rectangle;
    var mScaleW:Null<Float>;
    var mScaleH:Null<Float>;
    var mFilter : ObjectFilter;
    var mGroupPath : GroupPath;
    var parent : Sprite;

    public function new(inSvg:SVGData,?inLayer:String)
    {
		imageDependencies = new Map<String, BitmapData>();
		
		mSvg = inSvg;

		width = mSvg.width;
		height = mSvg.height;
		mRoot = mSvg;
		if (inLayer != null)
		{
			mRoot = mSvg.findGroup(inLayer);
			if (mRoot==null)
				throw "Could not find SVG group: " + inLayer;
		}
    }

    public static function toHaxe(inXML:Xml,?inFilter:ObjectFilter) : Array<String>
    {
       return new SVGRenderer(new SVGData(inXML,true)).iterate(new format.gfx.Gfx2Haxe(),inFilter).commands;
    }

    public static function toBytes(inXML:Xml,?inFilter:ObjectFilter) : format.gfx.GfxBytes
    {
       return new SVGRenderer(new SVGData(inXML,true)).iterate(new format.gfx.GfxBytes(),inFilter);
    }


    public function iterate<T>(inGfx:T, ?inFilter:ObjectFilter) : T
    {
       mGfx = cast inGfx;
       mMatrix = new Matrix();
       mFilter = inFilter;
       mGroupPath = [];
       mGfx.size(width,height);
       iterateGroup(mRoot,true);
       mGfx.eof();
       return inGfx;
    }
    public function hasGroup(inName:String)
    {
        return mRoot.hasGroup(inName);
    }

    public function iterateText(inText:Text)
    {
       if (mFilter!=null && !mFilter(inText.name,mGroupPath))
          return;
       mGfx.renderText(inText);
    }

    public function iterateImage(inImage:Image)
    {
		if (mFilter!=null && !mFilter(inImage.name, mGroupPath)) return;
       
		if (parent != null && inImage.visible) {

			if (inImage.bitmap.bitmapData == null) {

				if (imageDependencies.exists(inImage.href)) {
					var imageDependency = imageDependencies[inImage.href];

					if (imageDependency != null) {
						inImage.bitmap.bitmapData = imageDependency;
						inImage.copyDataToBitmap();
					}
				} else {
					if (StringTools.startsWith(inImage.href, "data:")) {
						// Data URI for image bytes
						var mimeType = inImage.href.split(";")[0].substr(5);
						var imageBytes = haxe.crypto.Base64.decode(inImage.href.substr(inImage.href.indexOf(",") + 1));

						//TODO:
					} else {
						imageDependencies[inImage.href] = null;
						if (loadImageCallback != null) loadImageCallback(inImage);
					}
				}
			} else {
				if (loadImageCallback != null) loadImageCallback(inImage);
			}
		}
	}
   
    public function iteratePath(inPath:Path)
    {
       if (mFilter!=null && !mFilter(inPath.name,mGroupPath))
          return;

       if (inPath.segments.length==0 || mGfx==null)
           return;
       var px = 0.0;
       var py = 0.0;

       var m:Matrix  = inPath.matrix.clone();
       m.concat(mMatrix);
       var context = new RenderContext(m,mScaleRect,mScaleW,mScaleH);

       var geomOnly = mGfx.geometryOnly();
       if (!geomOnly)
       {
          // Move to avoid the case of:
          //  1. finish drawing line on last path
          //  2. set fill=something
          //  3. move (this draws in the fill)
          //  4. continue with "real" drawing
          inPath.segments[0].toGfx(mGfx, context);

          if (inPath.stroke_colour==null || inPath.stroke_colour==StrokeNone)
          {
             //mGfx.lineStyle();
          }
          else if (inPath.stroke_style == StrokeStyle.OUTSIDE)
          {
             var style = new format.gfx.LineStyle();
             var scale = Math.sqrt(m.a*m.a + m.d*m.d)/SQRT2;
             style.thickness = inPath.stroke_width*scale;
             style.capsStyle = inPath.stroke_caps;
             style.jointStyle = inPath.joint_style;
             style.miterLimit = inPath.miter_limit;
             
             var g = null;
             switch(inPath.stroke_colour)
             {
                case StrokeGrad(grad):
                   grad.bounds = {xmin:15, ymin:-15, xmax:926, ymax:668}; //inPath.getBounds();
                   grad.updateMatrix(m);
                   g = grad;
                case StrokeSolid(colour, alpha):
                   style.alpha = inPath.stroke_alpha*inPath.alpha*alpha;
                   style.color = colour;
                case StrokeNone:
                   //mGfx.lineStyle();
             }
             mGfx.lineStyle(style);
             if (g!=null)
               mGfx.lineGradientStyle(g);
 
             for(segment in inPath.segments)
               segment.toGfx(mGfx, context);
  
             mGfx.endLineStyle(); 
          }

          switch(inPath.fill)
          {
             case FillGrad(grad):
                grad.bounds = inPath.getBounds();
                grad.updateMatrix(m);
                mGfx.beginGradientFill(grad);
             case FillSolid(colour, alpha):
                mGfx.beginFill(colour,inPath.fill_alpha*inPath.alpha*alpha);
             case FillNone:
                //mGfx.endFill();
          }


          if (inPath.stroke_colour==null || inPath.stroke_colour==StrokeNone)
          {
             //mGfx.lineStyle();
          }
          else if (inPath.stroke_style == StrokeStyle.BOTH)
          {
             var style = new format.gfx.LineStyle();
             var scale = Math.sqrt(m.a*m.a + m.d*m.d)/SQRT2;
             style.thickness = inPath.stroke_width*scale;
             style.capsStyle = inPath.stroke_caps;
             style.jointStyle = inPath.joint_style;
             style.miterLimit = inPath.miter_limit;

             var g = null;
             switch(inPath.stroke_colour)
             {
                case StrokeGrad(grad):
                   grad.bounds = inPath.getBounds();
                   grad.updateMatrix(m);
                   g = grad;
                case StrokeSolid(colour, alpha):
                   style.alpha = inPath.stroke_alpha*inPath.alpha*alpha;
                   style.color = colour;
                case StrokeNone:
                   //mGfx.lineStyle();
             }
             mGfx.lineStyle(style);
             if (g!=null)
               mGfx.lineGradientStyle(g);
          }

          for(segment in inPath.segments)
             segment.toGfx(mGfx, context);

          if (inPath.stroke_colour!=null && inPath.stroke_style == StrokeStyle.BOTH)  
             mGfx.endLineStyle(); 

       }

       // endFill automatically close an open path
       // by putting endLineStyle before endFill, the closing line is not drawn
       // so an open path in inkscape stay open in openfl
       // this does not affect closed path
       
       mGfx.endFill();
    }



    public function iterateGroup(inGroup:Group,inIgnoreDot:Bool,separateGraphics:Bool = false)
    {
		// Convention for hidden layers ...
		if (inIgnoreDot && inGroup.name !=null && inGroup.name.substr(0,1) == ".")
			return;

		mGroupPath.push(inGroup.name);

		// if (mFilter!=null && !mFilter(inGroup.name)) return;
		for(child in inGroup.children)
		{
			switch(child)
			{
				case DisplayGroup(group):
					var oldParent = parent;
					if (separateGraphics) {
						var s:Sprite = cast parent.getChildByName(group.name);
						if (s == null) {
							s = new Sprite();
							s.name = group.name;
							parent.addChild( s );
						}
						s.graphics.clear();
						mGfx = new format.gfx.GfxGraphics(s.graphics);
						parent = s;
					}
					iterateGroup(group,inIgnoreDot,separateGraphics);
					if (separateGraphics) {
						parent = oldParent;
					}
				case DisplayPath(path):
					iteratePath(path);
				case DisplayText(text):
					iterateText(text);
				case DisplayImage(image):
					image.parentGroupName = inGroup.name;
					iterateImage(image);
			}
		}
       
		mGroupPath.pop();
	}

    public function render(inGfx:Graphics,?inMatrix:Matrix, ?inFilter:ObjectFilter, ?inScaleRect:Rectangle,?inScaleW:Float, ?inScaleH:Float )
    {
    
       mGfx = new format.gfx.GfxGraphics(inGfx);
       if (inMatrix==null)
          mMatrix = new Matrix();
       else
          mMatrix = inMatrix.clone();

       mScaleRect = inScaleRect;
       mScaleW = inScaleW;
       mScaleH = inScaleH;
       mFilter = inFilter;
       mGroupPath = [];

       iterateGroup(mRoot,inFilter==null);
    }
    public function renderRect(inGfx:Graphics,inFilter:ObjectFilter,scaleRect:Rectangle,inBounds:Rectangle,inRect:Rectangle) : Void
    {
       var matrix = new Matrix();
       matrix.tx = inRect.x-(inBounds.x);
       matrix.ty = inRect.y-(inBounds.y);
       if (scaleRect!=null)
       {
          var extraX = inRect.width-(inBounds.width-scaleRect.width);
          var extraY = inRect.height-(inBounds.height-scaleRect.height);
          render(inGfx,matrix,inFilter,scaleRect, extraX, extraY );
       }
       else
         render(inGfx,matrix,inFilter);
    }

    public function renderRect0(inGfx:Graphics,inFilter:ObjectFilter,scaleRect:Rectangle,inBounds:Rectangle,inRect:Rectangle) : Void
    {
       var matrix = new Matrix();
       matrix.tx = -(inBounds.x);
       matrix.ty = -(inBounds.y);
       if (scaleRect!=null)
       {
          var extraX = inRect.width-(inBounds.width-scaleRect.width);
          var extraY = inRect.height-(inBounds.height-scaleRect.height);
          render(inGfx,matrix,inFilter,scaleRect, extraX, extraY );
       }
       else
         render(inGfx,matrix,inFilter);
    }




    public function getExtent(?inMatrix:Matrix, ?inFilter:ObjectFilter, ?inIgnoreDot:Bool ) :
        Rectangle
    {
       if (inIgnoreDot==null)
          inIgnoreDot = inFilter==null;
       var gfx = new format.gfx.GfxExtent();
       mGfx = gfx;
       if (inMatrix==null)
          mMatrix = new Matrix();
       else
          mMatrix = inMatrix.clone();

       mFilter = inFilter;
       mGroupPath = [];

       iterateGroup(mRoot,inIgnoreDot);

       return gfx.extent;
    }

    public function findText(?inFilter:ObjectFilter)
    {
       mFilter = inFilter;
       mGroupPath = [];
       var finder = new format.gfx.GfxTextFinder();
       mGfx = finder;
       iterateGroup(mRoot,false);
       return finder.text;
    }

    public function getMatchingRect(inMatch:EReg) : Rectangle
    {
       return getExtent(null, function(_,groups) {
          return groups[1]!=null && inMatch.match(groups[1]);
       }, false  );
    }

    public function renderObject(inObj:DisplayObject,inGfx:Graphics,
                    ?inMatrix:Matrix,?inFilter:ObjectFilter,inScale9:Rectangle)
    {
       render(inGfx,inMatrix,inFilter,inScale9);
       var rect = getExtent(inMatrix, function(_,groups) { return groups[1]==".scale9"; } );
		 // TODO:
		 /*
       if (rect!=null)
          inObj.scale9Grid = rect;
       #if !flash
       inObj.cacheAsBitmap = neash.Lib.IsOpenGL();
       #end
		 */
    }

    public function renderSprite(inObj:Sprite, ?inMatrix:Matrix,?inFilter:ObjectFilter, ?inScale9:Rectangle)
    {
       renderObject(inObj,inObj.graphics,inMatrix,inFilter,inScale9);
    }

    public function createShape(?inMatrix:Matrix,?inFilter:ObjectFilter, ?inScale9:Rectangle) : Shape
    {
       var shape = new Shape();
       renderObject(shape,shape.graphics,inMatrix,inFilter,inScale9);
       return shape;
    }

    public function namedShape(inName:String) : Shape
    {
       return createShape(null, function(name,_) { return name==inName; } );
    }


    public function renderBitmap(?inRect:Rectangle,inScale:Float = 1.0)
    {
       mMatrix = new Matrix(inScale,0,0,inScale, -inRect.x*inScale, -inRect.y*inScale);

       var w = Std.int(Math.ceil( inRect==null ? width : inRect.width*inScale ));
       var h = Std.int(Math.ceil( inRect==null ? width : inRect.height*inScale ));

       var bmp = new openfl.display.BitmapData(w,h,true,#if (neko && !haxe3) { a: 0x00, rgb: 0x000000 } #else 0x00000000 #end);

       var shape = new openfl.display.Shape();
       mGfx = new format.gfx.GfxGraphics(shape.graphics);

       mGroupPath = [];
       iterateGroup(mRoot,true);

       bmp.draw(shape);
       mGfx = null;

       return bmp;
    }

    public function renderGroup(inObj:Sprite, inGroup:Group = null)
    {
      var oldmRoot = mRoot;

      if (inGroup != null) {
        mRoot = inGroup;
      }

      inObj.graphics.clear();
      mGfx = new format.gfx.GfxGraphics(inObj.graphics);
      mMatrix = new Matrix();
      mGroupPath = [];

      iterateGroup(mRoot,false);

      mRoot = oldmRoot;
    }
  
    public function renderDisplayList(inObj:Sprite)
    {
       parent = inObj;
       mGfx = new format.gfx.GfxGraphics(inObj.graphics);
       mMatrix = new Matrix();
       mGroupPath = [];

       iterateGroup(mRoot,false,true);
    }
  

}

