
package format.svg;

import openfl.geom.Matrix;
import openfl.display.Bitmap;

class Image
{
   public function new() { }

   public var name:String;
   public var matrix:Matrix;
   public var x:Float;
   public var y:Float;
   public var width:Float;
   public var height:Float;
   public var href:String;
   public var bitmap:Bitmap;
   public var visible:Bool;
}
