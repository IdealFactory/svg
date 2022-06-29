package format.svg;

import openfl.geom.Matrix;
import openfl.geom.Rectangle;
import openfl.display.GradientType;
import openfl.display.SpreadMethod;
import openfl.display.InterpolationMethod;
import openfl.display.CapsStyle;
import openfl.display.JointStyle;
import openfl.display.LineScaleMode;

typedef PathSegments = Array<PathSegment>;

typedef PathBounds = {
   var xmin:Float;
   var ymin:Float;
   var xmax:Float;
   var ymax:Float;
}

class Path
{
   public function new() { }

   public var matrix:Matrix;
   public var name:String;
   public var font_size:Float;
   public var fill:FillType;
   public var alpha:Float;
   public var fill_alpha:Float;
   public var stroke_alpha:Float;
   public var stroke_colour:Null<Int>;
   public var stroke_width:Float;
   public var stroke_caps:CapsStyle;
   public var stroke_style:StrokeStyle;
   public var joint_style:JointStyle;
   public var miter_limit:Float;

   public var segments:PathSegments;

   public function getBounds():PathBounds {
      var r = { xmin: Math.POSITIVE_INFINITY, ymin: Math.POSITIVE_INFINITY, xmax: Math.NEGATIVE_INFINITY, ymax: Math.NEGATIVE_INFINITY };
      if (segments==null) return r;
      for (s in segments) {
         if (s.x < r.xmin) r.xmin = s.x;
         if (s.y < r.ymin) r.ymin = s.y;
         if (s.x > r.xmax) r.xmax = s.x;
         if (s.y > r.ymax) r.ymax = s.y;
      }
      return r;
   }
}
