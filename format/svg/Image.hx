
package format.svg;

import openfl.geom.Matrix;
import openfl.display.Bitmap;

class Image
{

	public var name:String;
	public var title:String;
	public var matrix:Matrix;
	public var x:Float;
	public var y:Float;
	public var width:Float;
	public var height:Float;
	public var uri:String;
	public var href:String;
	public var bitmap:Bitmap;
	public var visible:Bool;
	public var parentGroupName:String;

	// When false, the image is drawn by its transform at the supplied bitmap's
	// own resolution instead of being scaled to the SVG width/height box.
	public static var scaleToBounds:Bool = true;

	public function new() {}

	public function copyDataToBitmap():Void {
		bitmap.smoothing = true;
		if (scaleToBounds) {
			bitmap.x = x;
			bitmap.y = y;
			bitmap.width = width;
			bitmap.height = height;
			var m = bitmap.transform.matrix;
			m.concat(matrix);
			bitmap.transform.matrix = m;
		} else {
			bitmap.transform.matrix = matrix;
		}
	}

}
