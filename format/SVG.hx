package format;


import openfl.display.Graphics;
import openfl.display.Sprite;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;
import format.svg.SVGData;
import format.svg.SVGRenderer;


class SVG {
	
	
	public var data:SVGData;
	
	public function new (content:String, baseImagePath:String = "") {
		
		if (content != null) {
			
			data = new SVGData (Xml.parse (content), baseImagePath);
			
		}
		
	}
	
	
	public function render (graphics:Graphics, x:Float = 0, y:Float = 0, width:Int = -1, height:Int = -1, ?inLayer:String = null) {
		
		if (data == null) return;
		
		var matrix = new Matrix ();
		matrix.identity ();
		
		if (width > -1 && height > -1) {
			
			matrix.scale (width / data.width, height / data.height);
			
		}
		
		matrix.translate (x, y);
		
		var renderer = new SVGRenderer (data, inLayer);
		// renderer.baseImagePath = baseImagePath;

		renderer.render (graphics, matrix);
		
	}
	
	
	public function renderDisplayList (sprite:Sprite, x:Float = 0, y:Float = 0, width:Int = -1, height:Int = -1, ?inLayer:String = null) {
		
		if (data == null) return;
		
		if (width > -1 && height > -1) {
	
			sprite.scaleX =  width / data.width;
			sprite.scaleY = height / data.height;
			
		}
		
		sprite.x = x;
		sprite.y = y;
		
		var renderer = new SVGRenderer (data, inLayer);
		// renderer.baseImagePath = baseImagePath;

		renderer.renderDisplayList (sprite);
		
	}
}