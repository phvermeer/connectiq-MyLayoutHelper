import Toybox.Lang;
import Toybox.Graphics;
import Toybox.System;
import Toybox.Math;

module MyLayoutHelper{

    typedef IDrawable as interface{
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

    class RoundScreenHelper{

        // internal definitions
        hidden enum Quadrant{
            QUADRANT_TOP_RIGHT = 1,
            QUADRANT_TOP_LEFT = 2,
            QUADRANT_BOTTOM_LEFT = 4,
            QUADRANT_BOTTOM_RIGHT = 8,
        }
        hidden enum Direction{
            DIRECTION_RIGHT = 1,
            DIRECTION_TOP = 2,
            DIRECTION_LEFT = 4,
            DIRECTION_BOTTOM = 8,
            // defined combinations
            DIRECTION_TOP_RIGHT = 3,
            DIRECTION_TOP_LEFT = 6,
            DIRECTION_BOTTOM_LEFT = 12,
            DIRECTION_BOTTOM_RIGHT = 9,
        }

        // compact area data
        typedef Area as Array<Numeric>; // [xMin, xMax, yMin, yMax] with (0,0) as circle center;

        // protected vars
        hidden var limits as Area;
        hidden var r as Number;

        protected var debugInfo as Array<String> = [] as Array<String>;

        function initialize(options as {
            :xMin as Numeric,
            :xMax as Numeric,
            :yMin as Numeric,
            :yMax as Numeric,
        }){
            var ds = System.getDeviceSettings();
            if(ds.screenShape != System.SCREEN_SHAPE_ROUND){
                throw new MyTools.MyException("Screenshape is not supported");
            }

            var xMin = (options.hasKey(:xMin) ? options.get(:xMin) as Numeric : 0).toFloat();
            var xMax = (options.hasKey(:xMax) ? options.get(:xMax) as Numeric : ds.screenWidth).toFloat();
            var yMin = (options.hasKey(:yMin) ? options.get(:yMin) as Numeric : 0).toFloat();
            var yMax = (options.hasKey(:yMax) ? options.get(:yMax) as Numeric : ds.screenHeight).toFloat();
            r = ds.screenWidth / 2;
            limits = [xMin-r, xMax-r, yMin-r, yMax-r] as Area;
        }

        function setLimits(xMin as Numeric, xMax as Numeric, yMin as Numeric, yMax as Numeric) as Void{
            limits = [xMin-r, xMax-r, yMin-r, yMax-r] as Area;
        }

        function align(shape as IDrawable, alignment as Alignment|Number) as Void{
            // move object to outer limits in given align direction
            var obj = getArea(shape);

            // remove opposite alignment values
            if(alignment & (ALIGN_TOP|ALIGN_BOTTOM) == (ALIGN_TOP|ALIGN_BOTTOM)){
                alignment &= ~(ALIGN_TOP|ALIGN_BOTTOM);
            }
            if(alignment & (ALIGN_LEFT|ALIGN_RIGHT) == (ALIGN_LEFT|ALIGN_RIGHT)){
                alignment &= ~(ALIGN_LEFT|ALIGN_RIGHT);
            }

            // determine the align type (centered/horizontal/vertical/diagonal)
            var alignType = MyMath.countBitsHigh(alignment as Number); // 0 => centered), 1 => straight, 2 => diagonal

            if(alignment < 0 || alignment > 15){
                throw new MyTools.MyException(Lang.format("Unsupported align direction $1$", [alignment]));
            }
            if(alignType == 0){
                // centered
                throw new MyTools.MyException("Centered alignment is not (yet) supported");
            }else if(alignType == 2){
                // diagonal
                throw new MyTools.MyException("Diagonal alignment is not (yet) supported");
            }else if(alignType == 1){
                // straight
                // transpose to TOP alignment
                var direction = (alignment == ALIGN_TOP)
                    ? DIRECTION_TOP
                    : (alignment == ALIGN_LEFT)
                        ? DIRECTION_LEFT
                        : (alignment == ALIGN_BOTTOM)
                            ? DIRECTION_BOTTOM
                            : (alignment == ALIGN_RIGHT)
                                ? DIRECTION_RIGHT
                                : null;
                if(direction != null){
                    var obj_ = transposeArea(obj, direction, DIRECTION_TOP);
                    var limits_ = transposeArea(limits, direction, DIRECTION_TOP);

                    // ********* Do the top alignment ***********
                    // (x,y) with (0,0) at top left corner
                    // now use (X,Y) with (0,0) at circle center
                    var xMinL = limits_[0];
                    var xMaxL = limits_[1];
                    var yMinL = limits_[2];
                    var xMin = obj_[0];
                    var xMax = obj_[1];
                    var yMin = obj_[2];

                    // check if the width fits inside the boundaries
                    if((xMax - xMin) > (xMaxL - xMinL)){
                        throw new MyTools.MyException("shape cannot be aligned, shape outside limits");
                    }
                    // check space on top boundary within the circle
                    //   x² + y² = r²
                    //   x = ±√(r² - y²)
                    //   xMax = +√(r² - yMin²), xMin = -√(r² - yMin²) 
                    var r2 = r*r;
                    var xCircle = Math.sqrt(r2 - yMinL*yMinL);
                    var xMaxCalc = (xCircle < xMaxL) ? xCircle : xMaxL;
                    var xMinCalc = (-xCircle > xMinL) ? -xCircle : xMinL;

                    // check if the object fits against the top boundary
                    var w = xMax - xMin;
                    var dx = 0;
                    var dy = 0;
                    if((xMaxCalc - xMinCalc) >= w){
                        xMinCalc = 0.5 * (xMinCalc + xMaxCalc - w);
                        var yMinCalc = yMinL;
                        dx = xMinCalc - xMin;
                        dy = yMinCalc - yMin;
                    }else{
                        // move away from the border until the object fits
                        // needs space on circle both left and right or only left or right
                        var needsRight = false;
                        var needsLeft = false;
                        if(xMinL > -w/2){
                            needsRight = true;
                        }else if(xMaxL < w/2){
                            needsLeft = true;
                        }else{
                            needsLeft = true;
                            needsRight = true;
                        }
                        var xNeeded = (needsLeft && needsRight) // x needed for each circle side
                            ? 0.5f * w
                            : needsLeft
                                ? w - xMaxL
                                : w + xMinL;
                        // y² + x² = r²
                        // y = ±√(r² - x²)
                        var yMinCalc = - Math.sqrt(r2 - xNeeded*xNeeded);
                        xMinCalc = (xMinL > -xNeeded) ? xMinL : -xNeeded;
                        dx = xMinCalc - xMin;
                        dy = yMinCalc - yMin;
                    }
                    obj_[0] += dx;
                    obj_[1] += dx;
                    obj_[2] += dy;
                    obj_[3] += dy;

                    // transpose back to original orientation
                    obj = transposeArea(obj_, DIRECTION_TOP, direction);
                }
            }

            applyArea(obj, shape);
        }

        function resizeToMax(shape as IDrawable, keepAspectRatio as Boolean) as Void{
            // resize object to fit within outer limits
            debugInfo = [] as Array<String>;
            
            var aspectRatio = 1f * shape.width/shape.height;
            var obj = getArea(shape);
            var xMin = limits[0];
            var xMax = limits[1];
            var yMin = limits[2];
            var yMax = limits[3];
            try{

                // check in which quadrants the boundaries are outside the circle
                //                          ┌─────────┐
                //	                     ┌──┘    ·    └──┐  
                //	                   ┌─┘       ·       └─┐
                //	                   │      Q2 · Q1      │
                //	                   │ · · · · + · · · · │
                //	                   │      Q3 · Q4      │
                //	                   └─┐       ·       ┌─┘
                //	                     └──┐    ·    ┌──┘
                //	                        └─────────┘

                var r2 = r*r;
                var quadrants = 0;

                // check when corner limit is outside the circle
                var d = DIRECTION_TOP_RIGHT;
                for(var i=0; i<4; i++){
                    var x = (d & DIRECTION_LEFT > 0)? -xMin : xMax;
                    var y = (d & DIRECTION_TOP > 0)? -yMin : yMax;

                    if(x>0 && y>0 && (x*x + y*y > r2)){
                        var q = (d == DIRECTION_TOP_RIGHT)
                            ? QUADRANT_TOP_RIGHT
                            : (d == DIRECTION_TOP_LEFT)
                                ? QUADRANT_TOP_LEFT
                                : (d == DIRECTION_BOTTOM_LEFT)
                                    ? QUADRANT_BOTTOM_LEFT
                                    : QUADRANT_BOTTOM_RIGHT;

                        quadrants |= q;
                    }
                    d *= 2;
                }

                // determine the strategie for optimizing the size
                var quadrantCount = MyMath.countBitsHigh(quadrants);
                var exceededDirections = null;


                if(quadrantCount == 4){
                    debugInfo.add("4 quadrants: Reach with four corners to the circle");
                    obj = reachCircleEdge_4Points(aspectRatio);

                    // check if this is within the limits
                    exceededDirections = checkLimits(obj);
                    var exceededDirectionCount = MyMath.countBitsHigh(exceededDirections as Number);
                    if(exceededDirectionCount == 0){
                        applyArea(obj, shape);
                        return;
                    }else if(exceededDirectionCount ==2){
                        // scenario 1b: limitation on two opposite sides (tunnel)
                        var direction = (exceededDirections == DIRECTION_TOP | DIRECTION_BOTTOM)
                            ? DIRECTION_RIGHT
                            : (exceededDirections == DIRECTION_LEFT | DIRECTION_RIGHT )
                                ? DIRECTION_TOP
                                : null;
                        if(direction != null){
                            obj = reachTunnelLength4Points(aspectRatio, keepAspectRatio, direction);
                            applyArea(obj, shape);
                            return;

                        }else{
                            throw new MyTools.MyException("This is not supposed to happen!");
                        }
                        
                    }else{
                        // reduce quadrants where circle can be reached
                        if(exceededDirections & DIRECTION_TOP == DIRECTION_TOP){
                            quadrants &= ~(QUADRANT_TOP_LEFT|QUADRANT_TOP_RIGHT);
                        }
                        if(exceededDirections & DIRECTION_LEFT == DIRECTION_LEFT){
                            quadrants &= ~(QUADRANT_TOP_LEFT|QUADRANT_BOTTOM_LEFT);
                        }
                        if(exceededDirections & DIRECTION_BOTTOM == DIRECTION_BOTTOM){
                            quadrants &= ~(QUADRANT_BOTTOM_LEFT|QUADRANT_BOTTOM_RIGHT);
                        }
                        if(exceededDirections & DIRECTION_RIGHT == DIRECTION_RIGHT){
                            quadrants &= ~(QUADRANT_BOTTOM_RIGHT|QUADRANT_TOP_RIGHT);
                        }
                        quadrantCount = MyMath.countBitsHigh(quadrants);
                    }
                }

                if(quadrantCount == 3){
                    debugInfo.add("3 quadrants: I don't know what to do...");
                    throw new MyTools.MyException("3 Quadrants???");
                }

                if(quadrantCount == 2){
                    debugInfo.add("2 quadrants: Approach circle edge with two corners");
                    // approach circle edge with two corners
                    var direction = (quadrants == QUADRANT_TOP_LEFT | QUADRANT_TOP_RIGHT)
                        ? DIRECTION_TOP
                        : (quadrants == QUADRANT_TOP_LEFT | QUADRANT_BOTTOM_LEFT)
                            ? DIRECTION_LEFT
                            : (quadrants == QUADRANT_BOTTOM_LEFT | QUADRANT_BOTTOM_RIGHT)
                                ? DIRECTION_BOTTOM
                                : (quadrants == QUADRANT_TOP_RIGHT | QUADRANT_BOTTOM_RIGHT)
                                    ? DIRECTION_RIGHT
                                    : null;
                    if(direction != null){
                        obj = reachCircleEdge_2Points(aspectRatio, direction);
                        exceededDirections = checkLimits(obj);

                        if(exceededDirections == 0){
                            applyArea(obj, shape);
                            return;
                        }else{
                            // determine next scenario:
                            var _obj = transposeArea(obj, direction, DIRECTION_RIGHT);
                            var _limits = transposeArea(limits, direction, DIRECTION_RIGHT);
                            if(_obj[1] > _limits[1]){
                                // 1) exceeded limits in given direction (flattened circle)
                                direction = (direction & (DIRECTION_TOP|DIRECTION_BOTTOM) > 0)
                                    ? DIRECTION_RIGHT
                                    : DIRECTION_TOP;;
                                obj = reachTunnelLength4Points(aspectRatio, keepAspectRatio, direction);

                            }else{
                                // 2) exceeded limits on one or two sides
                            obj = reachTunnelLength2Points(aspectRatio, keepAspectRatio, direction);
                            }
                            exceededDirections = checkLimits(obj);
                            if(exceededDirections == 0){
                                applyArea(obj, shape);
                                return;
                            }
                        }

                    }else{
                        throw new MyTools.MyException("This is not supposed to happen!");
                    }
        
                    // use exceeded directions to determine next scenario
                    applyArea(obj, shape);
                    throw new MyTools.MyException("ToDo: approach circle edge with two corners");
                }

                if(quadrantCount == 1){
                    // approach circle edge with one corners
                    var quadrant = quadrants;
                    var direction = (quadrant == QUADRANT_TOP_RIGHT)
                        ? DIRECTION_TOP_RIGHT
                        : (quadrant == QUADRANT_TOP_LEFT)
                            ? DIRECTION_TOP_LEFT
                            : (quadrant == QUADRANT_BOTTOM_LEFT)
                                ? DIRECTION_BOTTOM_LEFT
                                : (quadrant == QUADRANT_BOTTOM_RIGHT)
                                    ? DIRECTION_BOTTOM_RIGHT
                                    : null;
                    if(direction != null){
                        obj = reachCircleEdge_1Point(aspectRatio, direction);
                        applyArea(obj, shape);
                        return;
                    }
                    throw new MyTools.MyException("ToDo: approach circle edge with one corners");
                }

                if(quadrantCount == 0){
                    // all within limits (rectangle)
                    if(keepAspectRatio){
                        obj = reachLimits(aspectRatio);
                    }else{
                        obj = limits;
                        }
                        applyArea(obj, shape);
                    return;
                }


            }catch(ex instanceof MyTools.MyException){
                ex.printStackTrace();
                for(var i=0; i<debugInfo.size(); i++){
                    System.println(debugInfo[i]);
                }
                System.println(ex.getErrorMessage());
                System.println(Lang.format("Limits: x=[$1$..$2$], y=[$3$..$4$]", limits));
                System.println(Lang.format("Result: x=[$1$..$2$], y=[$3$..$4$]", obj));
            }
        }

        // helper functions
        hidden function getArea(drawable as IDrawable) as Area{
            return [
                drawable.locX - r, 
                drawable.locX + drawable.width - r, 
                drawable.locY - r, 
                drawable.locY + drawable.height - r
            ] as Area;
        }
        hidden function applyArea(area as Area, drawable as IDrawable) as Void{
            var xMin = Math.ceil(area[0]).toNumber();
            var xMax = Math.floor(area[1]).toNumber();
            var yMin = Math.ceil(area[2]).toNumber();
            var yMax = Math.floor(area[3]).toNumber();
            drawable.locX = xMin + r;
            drawable.width = xMax - xMin;
            drawable.locY = yMin + r;
            drawable.height = yMax - yMin;
        }

        hidden function rotateArea(area as Area, nrOfQuadrants as Number) as Area{
            // to support negative numbers
            while(nrOfQuadrants<0){
                nrOfQuadrants += 4;
            }

            // to support numbers multiple rounds
            nrOfQuadrants %= 4;
            if(nrOfQuadrants == 1){
                return [area[2], area[3], -area[1], -area[0]] as Area;
            }else if(nrOfQuadrants == 2){
                return [-area[1], -area[0], -area[3], -area[2]] as Area;
            }else if(nrOfQuadrants == 3){
                return [-area[3], -area[2], area[0], area[1]] as Area;
            }else{
                return [area[0], area[1], area[2], area[3]] as Area;
            }
        }

        hidden function transposeArea(obj as Area, from as Direction, to as Direction) as Area{
            var counter = 0;
            // Direction values: 2^[0..3]
            while(from < to){
                counter++;
                from *= 2;
            }
            while(from > to){
                counter--;
                from /= 2;
            }
            return rotateArea(obj, counter);
        }

        hidden function checkLimits(area as Area) as Direction|Number{
            var exceededDirections = 0;
            if(area[0] < limits[0]){
                exceededDirections |= DIRECTION_LEFT;
            }
            if(area[1] > limits[1]){
                exceededDirections |= DIRECTION_RIGHT;
            }
            if(area[2] < limits[2]){
                exceededDirections |= DIRECTION_TOP;
            }
            if(area[3] > limits[3]){
                exceededDirections |= DIRECTION_BOTTOM;
            }
            return exceededDirections;
        }

		hidden function reachCircleEdge_4Points(aspectRatio as Decimal) as Area{
            debugInfo.add(Lang.format("reachCircleEdge_4Points(aspectRatio=$1$)",[aspectRatio]));
            // approach circle edge with all four corners
            var angle = Math.atan(1f/aspectRatio);
            var x = r * Math.cos(angle);
            var y = r * Math.sin(angle);

            return [-x, x, -y, y] as Area;
        }

		hidden function reachCircleEdge_2Points(aspectRatio as Decimal, direction as Direction) as Area{
            debugInfo.add(Lang.format("reachCircleEdge_2Points(aspectRatio=$1$, direction=$2$)",[aspectRatio, direction]));

			// will calculate the size to fit between left limit an right circle edge with given aspect ratio

            // transpose to orientation RIGHT
            var limits_ = transposeArea(limits, direction as Direction, DIRECTION_RIGHT);
            var ratio = (direction & (DIRECTION_LEFT|DIRECTION_RIGHT) > 0)
                ? aspectRatio
                : 1/aspectRatio;
            
			var xMin = limits_[0];

            //		yMax: the distance from the center to the limit corner touching the circle
            //		x: the distance from the center to both sides of the rectangle
            //
            //              r   ↑      ┌───────────┐
            //	     (radius)   ·    ┌─┘ |         └─┐
            //	                ·  ┌─┘   • · · · · · ○─┐ ↑ +y
            //	                ·  │     ·           · │ |
            //	                ─  │     ·   +       · │ ─
            //	                   │     ·           · │ |
            //	                   └─┐   • · · · · · ○─┘ ↓ -y
            //	                     └─┐ |         ┌─┘
            //	                       └───────────┘
            //	                         ←--→|←------→
            //                          xMin         x
            //                         (limit)
			//	formula1:
            //      r² = x² + y²
			//	formula2:
            //      ratio = width / height
			//		ratio = (x-xMin) / (2*y)
            //  combine:
            //      r² = y² + xMin² 
            //          => y² = r² - xMin²
            //      ratio = (x-xMin) / (2*y)
            //          => (2*y) * ratio = (x - xMin)
            //          => y = (x - xMin) / (2 * ratio)
            //      ((x - xMin) / (2 * ratio))² = r² - xMin²
            //  use abc formula to solve x
            //      => (x * 1/(2*ratio) - xMin/(2*ratio))² = r² - xMin²
            //      => x² * (1/(2*ratio))² - 2 * x * 1/(2*ratio) * xMin/(2*ratio) + (xMin/(2*ratio))² = r² - xMin²
            //  a = (1/(2*ratio))² = 1 / (2*ratio)²
            //  b = -2 * 1/(2*ratio) * xMin/(2*ratio) = -2 * xMin / (2*ratio)²
            //  c = (xMin/(2*ratio))² + xMin² - r²  = xMin² / (2*ratio)² + xMin² - r² = xMin² * (1/(2*ratio)² + 1) -r²

			var a = 1+Math.pow(1f/(ratio*2), 2);
			var b = -1f/(ratio*ratio*2) * xMin;
			var c = Math.pow(1f/(ratio*2) * xMin, 2) - r*r;
			var results = MyMath.getAbcFormulaResults(a, b, c);
			var x = results[1];
			var y = (x - xMin) / (ratio * 2);

            var obj_ = [xMin, x, -y, y] as Area;

            // and transpose back to the orininal orientation
            return transposeArea(obj_, DIRECTION_RIGHT, direction);
		}

		hidden function reachCircleEdge_1Point(ratio as Decimal, direction as Direction) as Area{
            debugInfo.add(Lang.format("reachCircleEdge_1Point(aspectRatio=$1$, direction=$2$)",[ratio, direction]));

            //                          ╭─────────╮
            //	                     ╭──╯         ╰──╮  
            //	                   ╭─╯               ╰─╮
            //	                   │                   │
            //	                   │       ┏━━━━━━┱╌╌╌╌┤
            //	                   │       ┃      ┃    │
            //	                   ╰─╮     ┃      ┃  ╭─╯
            //	                     ╰──╮  ┡━━━━━━╃──╯
            //	                        ╰──┴──────╯

            var limits_ = transposeArea(limits, direction, DIRECTION_BOTTOM_RIGHT);
            var ratio_ = (
                (direction == DIRECTION_BOTTOM_RIGHT) ||
                (direction == DIRECTION_TOP_LEFT))
                ? 1/ratio
                : ratio;

            var xMin = limits_[0];
            var yMin = limits_[2];
            //	formula1:
            //      r² = x² + y²
            //      => y² = r² - x²
            //  formula2:
            //      ratio = w / h = (x-xMin) / (y-yMin)
            //      => y-yMin = (x-xMin) / ratio
            //      => y = (x-xMin) / ratio + yMin
            //      => y = x/ratio - xMin/ratio + yMin
            //  combine:
            //      (x/ratio - xMin/ratio + yMin)² = r² - xMax²
            //      => xMax²/ratio² - 2*(xMin/ratio + yMin)*x/ratio + (xMin/ratio + yMin)² = r² - xMax²
            //      => (1/ratio²)*xMax²+xMax² - 2*((xMin/ratio + yMin)/ratio)*x + (xMin/ratio + yMin)² - r² = 0
            //  abc formula:
            //      a = (1/ratio²)+1
            //      b = -2*((xMin/ratio + yMin)/ratio)
            //      c = (xMin/ratio + yMin)² - r²
            var a = 1/(ratio_*ratio_) + 1;
            var b = -2 * (xMin/ratio_ + yMin)/ratio;
            var c = xMin/ratio_ + yMin;
            c = c*c - r*r;

            var results = MyMath.getAbcFormulaResults(a, b, c);

            var x = results[1];
            var y = x/ratio_ - xMin/ratio_ + yMin;

            return [xMin, x, yMin, y] as Area;
        }
 
        hidden function reachTunnelLength4Points(aspectRatio as Decimal, keepAspectRatio as Boolean, direction as Direction) as Area{
            debugInfo.add(Lang.format("reachTunnelLength4Points(aspectRatio=$1$, keepAspectRatio=$2$, direction=$3$)",[aspectRatio, keepAspectRatio, direction]));

            // limitation on two opposite sides (tunnel)
            //                          ╭┬───────┬╮
            //	                     ╭──╯╎       ╎╰──╮  
            //	                   ╭─╯   ┢━━━━━━━┪   ╰─╮
            //	                   │     ┃       ┃     │
            //	                   │     ┃       ┃     │
            //	                   │     ┃       ┃     │
            //	                   ╰─╮   ┡━━━━━━━┩   ╭─╯
            //	                     ╰──╮╎       ╎╭──╯
            //	                        ╰┴───────┴╯
            // (example with vertical orientation)

            var limits_ = transposeArea(limits, direction, DIRECTION_TOP);
            var ratio = (direction & (DIRECTION_TOP|DIRECTION_BOTTOM) > 0) ? aspectRatio : 1f / aspectRatio;
            var obj_ = limits_;

            var xMinL_ = limits_[0];
            var xMaxL_ = limits_[1];
            var yMinL_ = limits_[2];
            var yMaxL_ = limits_[3];

            if(keepAspectRatio){
                var widthL_ = xMaxL_ - xMinL_;
                var heightL_ = yMaxL_ - yMinL_;

                var height_ = widthL_ / ratio;
                var yMin_ = yMinL_ + (heightL_ - height_)/2;
                obj_ = [xMinL_, xMaxL_, yMin_, yMin_ + height_] as Area;
            }else{
                // get the side that is farest from the middle
                var xFar_ = (xMaxL_ > -xMinL_) ? xMaxL_ : -xMinL_;
                var y_ = Math.sqrt(r*r - xFar_*xFar_);
                obj_ = [xMinL_, xMaxL_, -y_, y_] as Area;
            }

            // rotate back to initial orientation
            return transposeArea(obj_, DIRECTION_TOP, direction);
        }

        hidden function reachTunnelLength2Points(aspectRatio as Decimal, keepAspectRatio as Boolean, direction as Direction) as Area{
            debugInfo.add(Lang.format("reachTunnelLength2Points(aspectRatio=$1$, keepAspectRatio=$2$, direction=$3$)",[aspectRatio, keepAspectRatio, direction]));
            // limitation on three sides (half tunnel)
            //                          ╭┬───────┬╮
            //	                     ╭──╯┢━━━━━━━┪╰──╮  
            //	                   ╭─╯   ┃       ┃   ╰─╮
            //	                   │     ┃       ┃     │
            //	                   │     ┡━━━━━━━┩     │
            //	                   │     └╌╌╌╌╌╌╌┘     │
            //	                   ╰─╮               ╭─╯
            //	                     ╰──╮         ╭──╯
            //	                        ╰─────────╯
            // (example with vertical orientation)

            var limits_ = transposeArea(limits, direction, DIRECTION_TOP);
            var aspectRatio_ = (direction == DIRECTION_TOP) ? aspectRatio : 1f / aspectRatio;
            var obj_ = limits_;

            var xMinL_ = limits_[0];
            var xMaxL_ = limits_[1];
            var yMinL_ = limits_[2];
            var yMaxL_ = limits_[3];

            // Get the available space
            // get the side that is farest from the middle
            var xFar_ = (xMaxL_ > -xMinL_) ? xMaxL_ : -xMinL_;
            var y_ = Math.sqrt(r*r - xFar_*xFar_);

            if(keepAspectRatio){
                var heightMax_ = yMaxL_ + y_;
                var widthL_ = xMaxL_ - xMinL_;
                var height_ = widthL_ * aspectRatio_;
                y_ += (heightMax_ - height_)/2;
                obj_ = [xMinL_, xMaxL_, y_, y_ + height_] as Area;
            }else{
                obj_ = [xMinL_, xMaxL_, -y_, yMaxL_] as Area;
            }

            // rotate back to initial orientation
            return transposeArea(obj_, DIRECTION_TOP, direction);
        }

        hidden function reachLimits(aspectRatio as Decimal) as Area{
            debugInfo.add(Lang.format("reachLimits(aspectRatio=$1$)",[aspectRatio]));

            var x = limits[0];
            var y = limits[2];
            var w = limits[1] - x;
            var h = limits[3] - y;
            var ratioL = w / h;
            if(ratioL > aspectRatio){
                var w2 = aspectRatio * h;
                x += (w - w2)/2;
                return [x, x+w2, y, y+h] as Area;                
            }else if(ratioL < aspectRatio) {
                var h2 = 1f * w / aspectRatio;
                y += (h - h2)/2;
                return [x, x+w, y, y+h2] as Area;
            }else{
                return [x, x+w, y, y+h] as Area;
            }
        }
    }
}