package format.svg;

enum FillType
{
   FillGrad(grad:Grad);
   FillSolid(colour:Int, alpha:Float);
   FillNone;
}

