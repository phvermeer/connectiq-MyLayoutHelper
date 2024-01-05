import Toybox.Lang;
import Toybox.System;
import MyMath;

module MyLayout{
    (:rectangle)
    class LayoutHelper{
        var xMin as Numeric;
        var xMax as Numeric;
        var yMin as Numeric;
        var yMax as Numeric;

        function initialize(options as {
            :xMin as Numeric,
            :xMax as Numeric,
            :yMin as Numeric,
            :yMax as Numeric,
            :margin as Number,
        }){
            var ds = System.getDeviceSettings();

            xMin = options.hasKey(:xMin) ? options.get(:xMin) as Numeric : 0;
            xMax = options.hasKey(:xMax) ? options.get(:xMax) as Numeric : ds.screenWidth;
            yMin = options.hasKey(:yMin) ? options.get(:yMin) as Numeric : 0;
            yMax = options.hasKey(:yMax) ? options.get(:yMax) as Numeric : ds.screenHeight;

            if(options.hasKey(:margin)){
                var margin = options.get(:margin) as Number;
                xMin += margin;
                xMax -= margin;
                yMin += margin;
                yMax -= margin;
            }
        }

        function setLimits(xMin as Numeric, xMax as Numeric, yMin as Numeric, yMax as Numeric, margin as Number) as Void{
            self.xMin = xMin + margin;
            self.xMax = xMax - margin;
            self.yMin = yMin + margin;
            self.yMax = yMax - margin;
        }

        function align(shape as IDrawable, alignment as Alignment|Number) as Void{
            var w = xMax - xMin;
            var h = yMax - yMin;
            var x;
            var y;
            if(alignment == ALIGN_TOP){
                x = xMin + (w - shape.width)/2;
                y = yMin;
            }else if(alignment == ALIGN_RIGHT){
                x = xMax - shape.width;
                y = yMin + (h - shape.height)/2;
            }else if(alignment == ALIGN_BOTTOM){
                x = xMin + (w - shape.width)/2;
                y = yMax - shape.height;
            }else if(alignment == ALIGN_LEFT){
                x = xMin;
                y = yMin + (h - shape.height)/2;
            }else if(alignment == ALIGN_TOP|ALIGN_RIGHT){
                x = xMax - shape.width;
                y = yMin;
            }else if(alignment == ALIGN_RIGHT|ALIGN_BOTTOM){
                x = xMax - shape.width;
                y = yMax - shape.height;
            }else if(alignment == ALIGN_BOTTOM|ALIGN_LEFT){
                x = xMin;
                y = yMax - shape.height;
            }else if(alignment == ALIGN_LEFT|ALIGN_TOP){
                x = xMin;
                y = yMin;
            }else{
                throw new InvalidValueException(Lang.format("Invalid alignment value ($1$) was provided",[alignment]));
            }

            shape.setLocation(x, y);
        }

        function resizeToMax(shape as IDrawable, keepAspectRatio as Boolean) as Void{
            var w = xMax - xMin;
            var h = yMax - yMin;
            var x = xMin;
            var y = yMin;
            if(keepAspectRatio){
                shape.setSize(w, h);
                shape.setLocation(xMin, yMin);
            }else{
                var aspectRatio = 1f * shape.width/shape.height;
                var w_ = aspectRatio * h;
                if(w > w_){
                    x += (w - w_) / 2;
                    w = w_;
                }else{
                    var h_ = w / aspectRatio;
                    y += (h - h_) / 2;
                    h = h_;
                }
            }
            shape.setSize(w, h);
            shape.setLocation(x, y);
        }
    }
}