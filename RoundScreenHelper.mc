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
        hidden var r as Float;

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
            r = 0.5 * ds.screenWidth;
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

            // calculate the following 2 variables to move the object
            var dx = 0;
            var dy = 0;

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
                var nrOfQuadrantsToRotate = (alignment == ALIGN_TOP)
                    ? 0
                    : (alignment == ALIGN_RIGHT)
                        ? 1
                        : (alignment == ALIGN_BOTTOM)
                            ? 2
                            : 3;
                var objRotated = rotateArea(obj, nrOfQuadrantsToRotate);
                var limitsRotated = rotateArea(limits, nrOfQuadrantsToRotate);

                // ********* Do the top alignment ***********
                // (x,y) with (0,0) at top left corner
                // now use (X,Y) with (0,0) at circle center
                var xMinL = limitsRotated[0];
                var xMaxL = limitsRotated[1];
                var yMinL = limitsRotated[2];
                var yMaxL = limitsRotated[3];
                var xMin = objRotated[0];
                var xMax = objRotated[1];
                var yMin = objRotated[2];
                var yMax = objRotated[3];

                // check if the width fits inside the boundaries
                if((xMax - xMin) > (xMaxL - xMinL)){
                    throw new MyTools.MyException("shape cannot be aligned, shape outside limits");
                }
                // check space on top boundary within the circle
                //   x² + y² = radius²
                //   x = ±√(radius² - y²)
                //   xMax = +√(radius² - yMin²), xMin = -√(radius² - yMin²) 
                var r2 = r*r;
                var xCircle = Math.sqrt(r2 - yMinL*yMinL);
                var xMaxCalc = (xCircle < xMaxL) ? xCircle : xMaxL;
                var xMinCalc = (-xCircle > xMinL) ? -xCircle : xMinL;

                // check if the object fits against the top boundary
                var w = xMax - xMin;
                var h = yMax - yMin;
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
                    // y² + x² = radius²
                    // y = ±√(radius² - x²)
                    var yMinCalc = - Math.sqrt(r2 - xNeeded*xNeeded);
                    xMinCalc = (xMinL > -xNeeded) ? xMinL : -xNeeded;
                    dx = xMinCalc - xMin;
                    dy = yMinCalc - yMin;
                }
                objRotated[0] += dx;
                objRotated[1] += dx;
                objRotated[2] += dy;
                objRotated[3] += dy;

                // transpose back to original orientation
                var objAligned = rotateArea(objRotated, -nrOfQuadrantsToRotate);

                // get the movement
                dx = objAligned[0] - obj[0];
                dy = objAligned[2] - obj[2];

            }

            shape.locX += dx;
            shape.locY += dy;
        }


        function resizeToMax(shape as IDrawable, keepAspectRatio as Boolean) as Void{
            // resize object to fit within outer limits

            var aspectRatio = 1f * shape.width/shape.height;
            var obj = getArea(shape);
            var xMin = limits[0];
            var xMax = limits[1];
            var yMin = limits[2];
            var yMax = limits[3];

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
            for(var d=DIRECTION_TOP_LEFT; d<16; d*=2){
                var x = (d & DIRECTION_LEFT > 0)? -xMin : xMax;
                var y = (d & DIRECTION_TOP > 0)? -yMin : yMax;

                if(x*x + y*y > r2){
                    var q = (d == DIRECTION_TOP_RIGHT)
                        ? QUADRANT_TOP_RIGHT
                        : (d == DIRECTION_TOP_LEFT)
                            ? QUADRANT_TOP_LEFT
                            : (d == DIRECTION_BOTTOM_LEFT)
                                ? QUADRANT_BOTTOM_LEFT
                                : QUADRANT_BOTTOM_RIGHT;

                    quadrants |= q;
                }
            }

            // determine the strategie for optimizing the size
            var quadrantCount = MyMath.countBitsHigh(quadrants);
            var exceededDirections = null;

            if(quadrantCount == 0){
                // all within limits (rectangle)
                if(keepAspectRatio){
                    var wL = xMax - xMin;
                    var hL = yMax - yMin;
                    var x = xMin;
                    var y = yMin;
                    var w = wL;
                    var h = hL;
                    var aspectRatioL = wL / hL;

                    if(aspectRatio > aspectRatioL){
                        w = 1f * hL / aspectRatio;
                        x += (wL-w)/2;
                    }else if(aspectRatio < aspectRatioL){
                        h = aspectRatio * wL;
                        y += (hL - h)/2;
                    }
                    obj = [x, x+w, y, y+w] as Area;
                    applyArea(obj, shape);
                }else{
                    applyArea(limits, shape);
                }
                return;
            }

            if(quadrantCount == 4){
                // approach circle edge with all four corners
                var angle = Math.atan(aspectRatio);
                var x = r * Math.cos(angle);
                var y = r * Math.sin(angle);

                obj = [-x, x, -y, y] as Area;

                // check if this is within the limits
                exceededDirections = checkLimits(obj);
                if(exceededDirections == 0){
                    applyArea(obj, shape);
                    return;
                }else if(exceededDirections ==2){
                    // limitation on two opposite sides (tunnel)
                    //                          ┌─────────┐
                    //	                     ┌──┘         └──┐  
                    //	                   ┌─┘ ·           · └─┐
                    //	                   │   ·           ·   │
                    //	                   │   ·           ·   │
                    //	                   │   ·           ·   │
                    //	                   └─┐ ·           · ┌─┘
                    //	                     └──┐         ┌──┘
                    //	                        └─────────┘
                    // (example with vertical orientation)

                    // transpose to vertical orientation
                    var nrOfQuadrants = (exceededDirections == (DIRECTION_TOP | DIRECTION_BOTTOM ))
                        ? 1
                        : (exceededDirections == (DIRECTION_LEFT | DIRECTION_RIGHT ))
                            ? 0
                            : null;

                    if(nrOfQuadrants != null){
                        var limits_ = rotateArea(limits, nrOfQuadrants);
                        var aspectRatio_ = (nrOfQuadrants % 2 == 0) ? aspectRatio : 1f / aspectRatio;
                        var obj_ = limits_;

                        var xMinL_ = limits_[0];
                        var xMaxL_ = limits_[1];
                        var yMinL_ = limits_[2];
                        var yMaxL_ = limits_[3];

                        if(keepAspectRatio){
                            var widthL_ = xMaxL_ - xMinL_;
                            var heightL_ = yMaxL_ - yMinL_;

                            var height_ = widthL_ * aspectRatio_;
                            var yMin_ = yMinL_ + (heightL_ - height_)/2;
                            obj_ = [xMinL_, xMaxL_, yMin_, yMin_ + height_];
                        }else{
                            // get the side that is farest from the middle
                            var xFar_ = (xMaxL_ > -xMinL_) ? xMaxL_ : -xMinL_;
                            var y_ = Math.sqrt(r*r - xFar_*xFar_);
                            obj_ = [xMinL_, xMaxL_, -y_, y_] as Area;
                        }

                        // rotate back to initial orientation
                        obj = rotateArea(obj_, -nrOfQuadrants);
                        applyArea(obj, shape);
                        return;

                    }else{
                        throw new MyTools.MyException("This is not supposed to happen!");
                    }
                    


                }else{
                    // reduce quadrants where circle can be reached
                    quadrants = 0;
                    if(exceededDirections & DIRECTION_TOP == DIRECTION_TOP){
                        quadrants |= QUADRANT_TOP_LEFT|QUADRANT_TOP_RIGHT;
                    }
                    if(exceededDirections & DIRECTION_LEFT == DIRECTION_LEFT){
                        quadrants |= QUADRANT_TOP_LEFT|QUADRANT_BOTTOM_LEFT;
                    }
                    if(exceededDirections & DIRECTION_BOTTOM == DIRECTION_BOTTOM){
                        quadrants |= QUADRANT_BOTTOM_LEFT|QUADRANT_BOTTOM_RIGHT;
                    }
                    if(exceededDirections & DIRECTION_RIGHT == DIRECTION_RIGHT){
                        quadrants |= QUADRANT_BOTTOM_RIGHT|QUADRANT_TOP_RIGHT;
                    }
                }
            }

            if(quadrantCount == 3){
                // what now?
            }

            if(quadrantCount == 2){
                // approach circle edge with two corners
                throw new MyTools.MyException("ToDo");
            }

            if(quadrantCount == 1){
                // approach circle edge with one corners
                throw new MyTools.MyException("ToDo");
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
            drawable.locX = area[0] + r;
            drawable.width = area[1] - area[0];
            drawable.locY = area[2] + r;
            drawable.height = area[3] - area[2];
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
    }
}