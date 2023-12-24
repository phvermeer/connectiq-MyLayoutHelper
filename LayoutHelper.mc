import Toybox.Lang;
import Toybox.System;

module MyLayoutHelper{

    typedef IDrawable as interface{
        function setLocation(x as Numeric, y as Numeric) as Void;
        function setSize(w as Numeric, h as Numeric) as Void;
        var locX as Numeric;
        var locY as Numeric;
        var width as Numeric;
        var height as Numeric;
    };

    enum Alignment{
        ALIGN_TOP = 1,
        ALIGN_RIGHT = 2,
        ALIGN_BOTTOM = 4,
        ALIGN_LEFT = 8,
    }

    typedef ILayoutHelper as interface{
        function initialize(options as {
            :xMin as Numeric,
            :xMax as Numeric,
            :yMin as Numeric,
            :yMax as Numeric,
            :margin as Number,
        }) as Void;
        function setLimits(xMin as Numeric, xMax as Numeric, yMin as Numeric, yMax as Numeric, margin as Number) as Void;
        function align(shape as IDrawable, alignment as Alignment|Number) as Void;
        function resizeToMax(shape as IDrawable, keepAspectRatio as Boolean) as Void;
    };
    function getLayoutHelper(options as { :screenShape as ScreenShape, :xMin as Numeric, :xMax as Numeric, :yMin as Numeric, :yMax as Numeric, :margin as Number }) as ILayoutHelper{
        var screenShape = options.get(:screenShape);
        if(screenShape == null){
            screenShape = System.getDeviceSettings().screenShape;
        }
        switch(screenShape){
            case System.SCREEN_SHAPE_ROUND:
                return new RoundScreenHelper(options);
//            case System.SCREEN_SHAPE_SEMI_ROUND:
            case System.SCREEN_SHAPE_RECTANGLE:
                return new SquareScreenHelper(options);
//            case System.SCREEN_SHAPE_SEMI_OCTAGON:
            default:
                throw new MyTools.MyException("This screen shape is not (yet) supported");
        }
    }
}