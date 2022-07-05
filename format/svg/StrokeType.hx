package format.svg;

enum StrokeType
{
    StrokeGrad(grad:Grad);
    StrokeSolid(colour:Int, alpha:Float);
    StrokeNone;
}
