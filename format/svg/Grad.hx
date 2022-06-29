package format.svg;

import openfl.geom.Matrix;
import openfl.geom.Rectangle;

import openfl.display.GradientType;
import openfl.display.SpreadMethod;
import openfl.display.InterpolationMethod;
import openfl.display.CapsStyle;
import openfl.display.JointStyle;
import openfl.display.LineScaleMode;

import format.svg.Path;

class Grad extends /*gm2d.gfx.Gradient*/format.gfx.Gradient
{
   public var gradMatrix:Matrix;
   public var radius:Float;
   public var x1:Float;
   public var y1:Float;
   public var x2:Float;
   public var y2:Float;
   public var x1Ratio:Float;
   public var y1Ratio:Float;
   public var x2Ratio:Float;
   public var y2Ratio:Float;

   var _bounds:PathBounds = { xmin: 0, ymin: 0, xmax: 0, ymax: 0 };
   public var bounds(get, set):PathBounds;

   function get_bounds():PathBounds {
      return _bounds;
   }
   function set_bounds(b:PathBounds):PathBounds {
      _bounds = b;
      x1 = x1Ratio == -1 && x1!=0 ? b.xmin : b.xmin + ((b.xmax - b.xmin) * (x1Ratio==-1 ? 0 : x1Ratio));
      x2 = x2Ratio == -1 && x2!=0 ? b.xmax : b.xmin + ((b.xmax - b.xmin) * (x2Ratio==-1 ? 0 : x2Ratio));
      y1 = y1Ratio == -1 && y1!=0 ? b.ymin : b.ymin + ((b.ymax - b.ymin) * (y1Ratio==-1 ? 0 : y1Ratio));
      y2 = y2Ratio == -1 && y2!=0 ? b.ymax : b.ymin + ((b.ymax - b.ymin) * (y2Ratio==-1 ? 0 : y2Ratio));
      return _bounds;
   }

   public function new(inType:GradientType)
   {
      super();
      type = inType;
      radius = 0.0;
      gradMatrix = new Matrix();
      x1 = 0.0;
      y1 = 0.0;
      x2 = 0.0;
      y2 = 0.0;
   }

   public function updateMatrix(inMatrix:Matrix)
   {
      var dx = x2 - x1;
      var dy = y2 - y1;
      var theta = Math.atan2(dy,dx);
      var len = Math.sqrt(dx*dx+dy*dy);

      var mtx = new Matrix();

      if (type==GradientType.LINEAR)
      {
         mtx.createGradientBox(1.0,1.0);
         mtx.scale(len,len);
      }
      else
      {
         if (radius!=0.0)
            focus = len/radius;

         mtx.createGradientBox(1.0,1.0);
         mtx.translate(-0.5,-0.5);
         mtx.scale(radius*2,radius*2);
      }

      mtx.rotate(theta);
      mtx.translate(x1,y1);
      mtx.concat(gradMatrix);
      mtx.concat(inMatrix);
      matrix = mtx;
   }


}

#if haxe3
typedef GradHash = haxe.ds.StringMap<Grad>;
#else
typedef GradHash = Hash<Grad>;
#end