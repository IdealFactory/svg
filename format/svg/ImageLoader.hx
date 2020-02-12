package format.svg;

import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Loader;
import openfl.events.Event;
import openfl.events.ProgressEvent;
import openfl.events.SecurityErrorEvent;
import openfl.events.HTTPStatusEvent;
import openfl.events.IOErrorEvent;
import openfl.net.URLRequest;
import haxe.io.Bytes;

class ImageLoader {

    public static function loadImage( url:String, onComplete:BitmapData->Void ) {
        var request = new URLRequest( url );
        var loader = new Loader();

        loader.contentLoaderInfo.addEventListener( Event.COMPLETE, function(e) {
            onComplete( cast(loader.content, Bitmap).bitmapData );
        });
        loader.contentLoaderInfo.addEventListener( Event.OPEN, function(e) trace("requestURL.OPEN:"+e) );
        loader.contentLoaderInfo.addEventListener( SecurityErrorEvent.SECURITY_ERROR, function(e) trace("requestURL.SECURITY_ERROR:"+e) );
        loader.contentLoaderInfo.addEventListener( HTTPStatusEvent.HTTP_STATUS, function(e) trace("requestURL.HTTP_STATUS:"+e) );
        loader.contentLoaderInfo.addEventListener( IOErrorEvent.IO_ERROR, function(e) trace("requestURL.IOErrorEvent:"+e) );
        loader.load( request );
    }
}