import Toybox.Lang;
import Toybox.Graphics;
import Toybox.System;
import Toybox.Math;

module MyLayoutHelper{
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
        var margin as Number;

        var debugInfo as Array<String> = [] as Array<String>;

        function initialize(options as {
            :xMin as Numeric,
            :xMax as Numeric,
            :yMin as Numeric,
            :yMax as Numeric,
            :margin as Number,
        }){
            var ds = System.getDeviceSettings();
            if(ds.screenShape != System.SCREEN_SHAPE_ROUND){
                throw new MyTools.MyException("Screenshape is not supported");
            }

            var xMin = (options.hasKey(:xMin) ? options.get(:xMin) as Numeric : 0).toFloat();
            var xMax = (options.hasKey(:xMax) ? options.get(:xMax) as Numeric : ds.screenWidth).toFloat();
            var yMin = (options.hasKey(:yMin) ? options.get(:yMin) as Numeric : 0).toFloat();
            var yMax = (options.hasKey(:yMax) ? options.get(:yMax) as Numeric : ds.screenHeight).toFloat();
            margin = options.hasKey(:margin) ? options.get(:margin) as Number : 0;
            r = ds.screenWidth / 2;
            limits = [xMin-r, xMax-r, yMin-r, yMax-r] as Area;
        }

        function getLimits() as Array<Numeric>{
            return [
                limits[0] + r,
                limits[1] + r,
                limits[2] + r,
                limits[3] + r,
            ] as Array<Numeric>;
        }

        function setLimits(xMin as Numeric, xMax as Numeric, yMin as Numeric, yMax as Numeric, margin as Number) as Void{
            limits = [xMin-r, xMax-r, yMin-r, yMax-r] as Area;
            self.margin = margin;
        }

        function align(shape as IDrawable, alignment as Alignment|Number) as Void{
            // apply margin on limits
            var r = self.r-margin;
            var limits = [
                self.limits[0] + margin,
                self.limits[1] - margin,
                self.limits[2] + margin,
                self.limits[3] - margin,
            ] as Area;

            // move object to outer limits in given align direction
            var area = getArea(shape);

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
                    var area_ = transposeArea(area, direction, DIRECTION_TOP);
                    var limits_ = transposeArea(limits, direction, DIRECTION_TOP);

                    // ********* Do the top alignment ***********
                    // (x,y) with (0,0) at top left corner
                    // now use (X,Y) with (0,0) at circle center
                    var xMinL = limits_[0];
                    var xMaxL = limits_[1];
                    var yMinL = limits_[2];
                    var xMin = area_[0];
                    var xMax = area_[1];
                    var yMin = area_[2];

                    var w = xMax - xMin;
                    var dx = 0;
                    var dy = 0;

                    // check if the width fits inside the boundaries
                    if((xMax - xMin) > (xMaxL - xMinL)){
                        //throw new MyTools.MyException("shape cannot be aligned, shape outside limits");
                        dy = yMinL - yMin;
                        dx = ((xMaxL+xMinL)-(xMax+xMin))/2;
                    }else{
                        // check space on top boundary within the circle
                        //   x² + y² = r²
                        //   x = ±√(r² - y²)
                        //   xMax = +√(r² - yMin²), xMin = -√(r² - yMin²) 
                        var r2 = r*r;
                        var xCircle = Math.sqrt(r2 - yMinL*yMinL);
                        var xMaxCalc = (xCircle < xMaxL) ? xCircle : xMaxL;
                        var xMinCalc = (-xCircle > xMinL) ? -xCircle : xMinL;

                        // check if the object fits against the top boundary
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
                    }
                    area_[0] += dx;
                    area_[1] += dx;
                    area_[2] += dy;
                    area_[3] += dy;

                    // transpose back to original orientation
                    area = transposeArea(area_, DIRECTION_TOP, direction);
                }
            }

            applyArea(area, shape);
        }

        hidden static function flipArea(area as Area, horizontalFlip as Boolean, verticalFlip as Boolean) as Void{
            if(horizontalFlip){
                var temp = area[0];
                area[0] = -area[1];
                area[1] = -temp;
            }
            if(verticalFlip){
                var temp = area[2];
                area[2] = -area[3];
                area[3] = -temp;
            }
        }

        function resizeToMax(shape as IDrawable, keepAspectRatio as Boolean) as Void{
            debugInfo = [] as Array<String>;

            // resize object to fit within outer limits

            // apply margin
            var r = self.r - margin;
            var limits = [
                self.limits[0] + margin,
                self.limits[1] - margin,
                self.limits[2] + margin,
                self.limits[3] - margin,
            ] as Area;

            // Flip x-axis and y-as to align to bottom-right
            var xFlipped = limits[1] < -limits[0];
            var yFlipped = limits[3] < -limits[2];
            flipArea(limits, xFlipped, yFlipped);

            var xMin = limits[0];
            var xMax = limits[1];
            var yMin = limits[2];
            var yMax = limits[3];

            var w = shape.width;
            var h = shape.height;
            var aspectRatio = (w==0 || h==0)
                ? 1f
                : 1f*w/h;
            debugInfo.add(Lang.format("ratio = w/h = $1$/$2$ = $3$", [w,h,aspectRatio]));

            // update the area with the final result
            var area = [xMin, xMax, yMin, yMax] as Area;

            try{
                var r2 = r*r;
                // Check if whole limit area is outside the circle
                if(xMin*xMax>=0 && yMin*yMax>=0 && xMin*xMin + yMin*yMin >= r2){
                    // impossible mission
                    throw new MyTools.MyException("invalid limits (outside the circle)");
                }

                // Check if all limits are within the circle
                if(xMax*xMax + yMax*yMax <= r2){
                    // all within limits check aspect ratio
                    if(keepAspectRatio){
                        w = xMax-xMin;
                        h = yMax-yMin;
                        var ratio = w/h;
                        if(ratio>aspectRatio){
                            var w_ = h*aspectRatio;
                            var dx = (w-w_)/2;
                            area[0] += dx;
                            area[1] -= dx;
                        }else{
                            var h_ = w/aspectRatio;
                            var dy = (h-h_)/2;
                            area[2] += dy;
                            area[3] -= dy;
                        }
                    }
                    return;
                }

                // Option 2: Try if all corners can be resized to the circle edges and still be within given limits
                // approach circle edge with all four corners
                var angle = Math.atan(1/aspectRatio);
                var x = r * Math.cos(angle);
                var y = r * Math.sin(angle);

                // Check if this will result in a valid result
                if(limits[0] < -x && limits[1] > x && limits[2] < -y && limits[3] > y){
                    area = [-x, x, -y, y] as Area;
                    debugInfo.add("Full Screen");
                    return;
                }

                // Try furher ...
                // use 4 test points on the circle edge to determine the correct calculation method

                //  p1(x,y) = (xCircle, yMax)
                var x1 = Math.sqrt(r2 - yMax*yMax);

                //  p2(x,y) = (xMin, yCircle)
                var y2 = Math.sqrt(r2 - xMin*xMin);

                //  p3(x,y) = (xCircle, -yMin)
                var x3 = Math.sqrt(r2 - yMin*yMin);

                //  p4(x,y) = (xMax, yCircle)
                var y4 = Math.sqrt(r2 - xMax*xMax);

                // check valid ratio for Full Tunnel (horizontal) 
                area = [-x1, x1, yMin, yMax] as Area;
                if(-x1 >= xMin && x1 <=xMax){
                    h = area[3]-area[2];
                    w = area[1]-area[0];
                    if(h==0 || aspectRatio < w/h){
                        // apply this method
                        if(keepAspectRatio){
                            // use aspect ratio
                            var w_ = h*aspectRatio;
                            var dx = (w-w_)/2;
                            area[0] += dx;
                            area[1] -= dx;
                        }
                        debugInfo.add("Full Tunnel (horizontal)");
                        return; 
                    }
                }else{
                    // check valid ratio for Half Tunnel (to right)
                    area = [xMin, x1, yMin, yMax] as Area;
                    if(x1 <= xMax){
                        w = area[1]-area[0];
                        h = area[3]-area[2];
                        if(h==0 || aspectRatio < w/h){
                            // apply this method
                            if(keepAspectRatio){
                                var w_ = h * aspectRatio;
                                var dx = (w - w_)/2;
                                area[0] += dx;
                                area[1] -= dx;
                            }
                            debugInfo.add("Half Tunnel (to left/right)");
                            return;
                        }
                    }
                }

                // check valid ratio for Full Tunnel (vertical) 
                area = [xMin, xMax, -y4, y4] as Area;
                if(-y4 >= yMin && y4 <= yMax){
                    h = area[3]-area[2];
                    w = area[1]-area[0];
                    if(h != 0 && aspectRatio > w/h){
                        // apply this method
                        if(keepAspectRatio){
                            // use aspect ratio
                            var h_ = w / aspectRatio;
                            var dy = (h-h_)/2;
                            area[2] += dy;
                            area[3] -= dy;
                        }
                        debugInfo.add("Full Tunnel (vertical)");
                        return; 
                    }
                }else{
                    // check valid ratio for Half Tunnel (to bottom)
                    area = [xMin, xMax, yMin, y4] as Area;
                    h = area[3]-area[2];
                    if(h > 0 && y4 <= yMax){
                        w = area[1]-area[0];
                        var ratio = w/h;
                        if(aspectRatio > ratio){
                            // apply this method
                            if(keepAspectRatio){
                                var h_ = w / aspectRatio;
                                var dy = (h - h_)/2;
                                area[2] += dy;
                                area[3] -= dy;
                            }
                            debugInfo.add("Half Tunnel (top/bottom)");
                            return;
                        }
                    }
                }

                // valid ratio for Half Screen (to right)
                x = x3 > xMin ? x3 : xMin;
                area = [xMin, x, yMin, -yMin] as Area;
                h = area[3]-area[2];
                if(h>0 && x <= xMax && -yMin <= yMax){
                    w = area[1]-area[0];
                    var ratio = w/h;
                    if(aspectRatio > ratio){
                        // apply this method

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
                        //      r² = y² + x² 
                        //          => y² = r² - x²
                        //      ratio = (x-xMin) / (2*y)
                        //          => (2*y) * ratio = (x - xMin)
                        //          => y = (x - xMin) / (2 * ratio)
                        //  commbine
                        //      ((x - xMin) / (2 * ratio))² = r² - x²
                        //  use abc formula to solve x
                        //      => (x - xMin)²/(2 * ratio)² - r² + x² = 0
                        //      => (x² - 2*xMin*x + xMin²)/(4*ratio²) - r² + x² = 0
                        //      => (1 + 1/(4*ratio²)) * x² + (-2*xMin/(4*ratio²)) * x + (xMin²/(4*ratio²) - r²) = 0
                        // N = 4*ratio²
                        //  a = 1 + 1/N
                        //  b = -2*xMin/N
                        //  c = xMin²/N - r²
                        debugInfo.add("Half Screen (to left/right)");

                        var N = 4*aspectRatio*aspectRatio;
                        var a = 1+1/N;
                        var b = -2*xMin/N;
                        var c = xMin*xMin/N - r*r;
                       
                        var results = MyMath.getAbcFormulaResults(a, b, c);
                        x = results[1];
                        y = (x - xMin) / (aspectRatio * 2);
                        area = [xMin, x, -y, y] as Area;
                        return;
                    }
                }

                // valid ratio for Half Screen (to bottom)
                y = y2 > yMin ? y2 : yMin;
                area = [xMin, -xMin, yMin, y] as Area;
                if(y <= yMax && -xMin <= xMax){
                    h = area[3]-area[2];
                    w = area[1]-area[0];
                    if(h==0 || aspectRatio < w/h){
                        // apply this method
                        debugInfo.add("Half Screen (to top/bottom)");

                        var N = 4/(aspectRatio*aspectRatio);
                        debugInfo.add(Lang.format("aspectRatio=$1$, N=$2$, yMin=$3$", [aspectRatio, N, yMin]));

                        var a = 1+1/N;
                        var b = -2*yMin/N;
                        var c = yMin*yMin/N - r*r;
                        debugInfo.add(Lang.format("a=$1$, b=$2$, c=$3$", [a, b, c]));

                        var results = MyMath.getAbcFormulaResults(a, b, c);
                        y = results[1];
                        x = (y - yMin) / (2f/aspectRatio);
                        debugInfo.add(Lang.format("x,y = $1$,$2$", [x, y]));
                        area = [-x, x, yMin, y] as Area;
                        return;
                    }
                }

                // valid ratio for Single Egde (to bottom-right)
                if(-x1 > xMin  || -y2 > yMin){
                    //                          ╭─────────╮
                    //	                     ╭──╯         ╰──╮  
                    //	                   ╭─╯               ╰─╮
                    //	                   │                   │
                    //	                   │       ┏━━━━━━┱╌╌╌╌┤
                    //	                   │       ┃      ┃    │
                    //	                   ╰─╮     ┃      ┃  ╭─╯
                    //	                     ╰──╮  ┡━━━━━━╃──╯
                    //	                        ╰──┴──────╯
                    //	formula1:
                    //      r² = x² + y²
                    //      => x² = r² - y²
                    //  formula2:
                    //      ratio = w / h = (x-xMin) / (y-yMin)
                    //      => (x-xMin) = (y-yMin) * ratio
                    //      => x = y * ratio + (xMin - yMin * ratio) = y * ratio + C where C = (xMin - yMin * ratio)
                    //  combine:
                    //      (y * ratio + C)² = r² - y²
                    //      y² * ratio² +       y * (2 * ratio * C) + C² = r² - y²
                    //      y² * (1 + ratio²) + y * (2 * ratio * C) + (C² - r²) = 0

                    //  abc formula:
                    //      a = 1 + ratio²
                    //      b = 2 * ratio * C
                    //      c = C² - r²
                    //  where C = (xMin - yMin * ratio)
                    var C = xMin - yMin * aspectRatio;
                    var a = 1 + aspectRatio * aspectRatio;
                    var b = 2 * aspectRatio * C;
                    var c = C*C - r*r;

                    var results = MyMath.getAbcFormulaResults(a, b, c);
                    y = results[1];
                    x = y * aspectRatio + C;
                    area = [xMin, x, yMin, y] as Area;
                    debugInfo.add("Single Egde (to bottom-right)");

                }else{ // if(valid3 || valid4){
                    var C = yMin - xMin / aspectRatio;
                    var a = 1 + 1/(aspectRatio * aspectRatio);
                    var b = 2 * C / aspectRatio;
                    var c = C*C - r*r;

                    var results = MyMath.getAbcFormulaResults(a, b, c);
                    x = results[1];
                    y = x / aspectRatio + C;
                    area = [xMin, x, yMin, y] as Area;
                    debugInfo.add("Single Egde (to bottom-right)");
                }

            }catch(ex instanceof MyTools.MyException){
                ex.printStackTrace();
                for(var i=0; i<debugInfo.size(); i++){
                    System.println(debugInfo[i]);
                }
                System.println(ex.getErrorMessage());
                System.println(Lang.format("Limits: x=[$1$..$2$], y=[$3$..$4$]", limits));
                System.println(Lang.format("Result: x=[$1$..$2$], y=[$3$..$4$]", area));
            }finally{
                debugInfo.add("aspectRatio: "+aspectRatio.toString());
                // revert the flip
                flipArea(area, xFlipped, yFlipped);
                applyArea(area, shape);
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
            drawable.setLocation(xMin + r, yMin + r);
            drawable.setSize(xMax - xMin, yMax - yMin);
        }

        hidden static function rotateArea(area as Area, nrOfQuadrants as Number) as Area{
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

        hidden static function transposeArea(obj as Area, from as Direction, to as Direction) as Area{
            var counter = 0;
            var max = 4;
            var mask = 15;
            // Direction values: 2^[0..3]
            while(from != to && counter < max){
                from = from << 1; // shift bits
                from += (from/16); // overflow bits will be added at the front
                from &= mask;
                counter++;
            }
            if(from != to){
                System.println(Lang.format("transposeArea(from=$1$, to=$2$) FAILED", [from, to]));
            }
            return rotateArea(obj, counter);
        }

        hidden static function rotateDirections(direction as Direction, count as Number) as Direction{
            var mask = 15;
            direction = direction << count;
            direction += direction/16;
            direction &= mask;
            return direction as Direction;
        }

        hidden static function checkLimits(limits as Area, area as Area) as Direction|Number{
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
/*
		hidden static function reachCircleEdge_4Points(r as Number, aspectRatio as Decimal) as Area{
            // approach circle edge with all four corners
            var angle = Math.atan(1f/aspectRatio);
            var x = r * Math.cos(angle);
            var y = r * Math.sin(angle);

            return [-x, x, -y, y] as Area;
        }

		hidden static function reachCircleEdge_2Points(r as Number, limits as Area, aspectRatio as Decimal, direction as Direction) as Area{
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
            //      r² = y² + x² 
            //          => y² = r² - x²
            //      ratio = (x-xMin) / (2*y)
            //          => (2*y) * ratio = (x - xMin)
            //          => y = (x - xMin) / (2 * ratio)
            //  commbine
            //      ((x - xMin) / (2 * ratio))² = r² - x²
            //  use abc formula to solve x
            //      => (x - xMin)²/(2 * ratio)² - r² + x² = 0
            //      => (x² - 2*xMin*x + xMin²)/(4*ratio²) - r² + x² = 0
            //      => (1 + 1/(4*ratio²)) * x² + (-2*xMin/(4*ratio²)) * x + (xMin²/(4*ratio²) - r²) = 0
            // N = 4*ratio²
            //  a = 1 + 1/N
            //  b = -2*xMin/N
            //  c = xMin²/N - r²

            var N = 4*ratio*ratio;
            var a = 1+1/N;
            var b = -2*xMin/N;
            var c = xMin*xMin/N - r*r;
            
			var results = MyMath.getAbcFormulaResults(a, b, c);
			var x = results[1];
			var y = (x - xMin) / (ratio * 2);

            var obj_ = [xMin, x, -y, y] as Area;

            // and transpose back to the orininal orientation
            return transposeArea(obj_, DIRECTION_RIGHT, direction);
		}

		hidden static function reachCircleEdge_1Point(r as Number, limits as Area, ratio as Decimal, corner as Direction) as Area{
            //                          ╭─────────╮
            //	                     ╭──╯         ╰──╮  
            //	                   ╭─╯               ╰─╮
            //	                   │                   │
            //	                   │       ┏━━━━━━┱╌╌╌╌┤
            //	                   │       ┃      ┃    │
            //	                   ╰─╮     ┃      ┃  ╭─╯
            //	                     ╰──╮  ┡━━━━━━╃──╯
            //	                        ╰──┴──────╯

            var limits_ = transposeArea(limits, corner, DIRECTION_BOTTOM_RIGHT);
            var ratio_ = (
                (corner == DIRECTION_BOTTOM_RIGHT) ||
                (corner == DIRECTION_TOP_LEFT))
                ? 1/ratio
                : ratio;

            var xMin = limits_[0];
            var xMax = limits_[1];
            var yMin = limits_[2];
            var yMax = limits_[3];
            //	formula1:
            //      r² = x² + y²
            //      => x² = r² - y²
            //  formula2:
            //      ratio = w / h = (x-xMin) / (y-yMin)
            //      => (x-xMin) = (y-yMin) * ratio
            //      => x = y * ratio + (xMin - yMin * ratio) = y * ratio + C where C = (xMin - yMin * ratio)
            //  combine:
            //      (y * ratio + C)² = r² - y²
            //      y² * ratio² +       y * (2 * ratio * C) + C² = r² - y²
            //      y² * (1 + ratio²) + y * (2 * ratio * C) + (C² - r²) = 0

            //  abc formula:
            //      a = 1 + ratio²
            //      b = 2 * ratio * C
            //      c = C² - r²
            //  where C = (xMin - yMin * ratio)
            var C = xMin - yMin * ratio_;
            var a = 1 + ratio_ * ratio_;
            var b = 2 * ratio_ * C;
            var c = C*C - r*r;

            var results = MyMath.getAbcFormulaResults(a, b, c);

            var y = results[1];
            var x = y * ratio_ + C;

            var obj_ = [xMin, x, yMin, y] as Area;
            
            // Check limits (do it here, because the direction is standarized here)
            var exceededDirections = checkLimits(limits_, obj_);
            if(exceededDirections != 0){
                // reach tunnel single corner
                if(exceededDirections == DIRECTION_RIGHT){
                    // limited by xMax => calculate y
                    x = xMax;
                    y = Math.sqrt(r*r-x*x);
                }else if(exceededDirections == DIRECTION_BOTTOM){
                    // limited by yMax => calculate x
                    y = yMax;
                    x = Math.sqrt(r*r-y*y);
                }
                obj_ = [xMin, x, yMin, y] as Area;
            }
            var obj = transposeArea(obj_, DIRECTION_BOTTOM_RIGHT, corner);
            return obj;
        }
 
        hidden static function reachTunnelLength4Points(r as Number, limits as Area, aspectRatio as Decimal, keepAspectRatio as Boolean, direction as Direction) as Area{
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

        hidden static function reachTunnelLength2Points(r as Number, limits as Area, aspectRatio as Decimal, keepAspectRatio as Boolean, direction as Direction) as Area{
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
            var aspectRatio_ = (direction & (DIRECTION_TOP | DIRECTION_BOTTOM) > 0)? aspectRatio : 1f / aspectRatio;
            var obj_ = limits_;

            var xMinL_ = limits_[0];
            var xMaxL_ = limits_[1];
            // var yMinL_ = limits_[2];
            var yMaxL_ = limits_[3];

            // Get the available space
            // get the side that is farest from the middle
            var xFar_ = (xMaxL_ > -xMinL_) ? xMaxL_ : -xMinL_;
            var y_ = Math.sqrt(r*r - xFar_*xFar_);

            if(keepAspectRatio){
                var heightMax_ = yMaxL_ + y_;
                var widthL_ = xMaxL_ - xMinL_;
                var height_ = widthL_ / aspectRatio_;
                y_ -= (heightMax_ - height_)/2;
                obj_ = [xMinL_, xMaxL_, -y_, -y_ + height_] as Area;
            }else{
                obj_ = [xMinL_, xMaxL_, -y_, yMaxL_] as Area;
            }

            // rotate back to initial orientation
            return transposeArea(obj_, DIRECTION_TOP, direction);
        }

        hidden static function reachFlattenedCircle(r as Number, limits as Area, aspectRatio as Decimal, keepAspectRatio as Boolean, direction as Direction) as Area{
            var limits_ = transposeArea(limits, direction, DIRECTION_RIGHT);
            var ratio = (direction & (DIRECTION_RIGHT | DIRECTION_LEFT) > 0)
                ? aspectRatio
                : 1/aspectRatio;

            var xMin = limits_[0];
            var xMax = limits_[1];

            var obj_ = null;
            if(keepAspectRatio){
                // get area with given ratio between xMin and xMax
                var w = xMax - xMin;
                var h = w / ratio;
                var y = h/2;
                obj_ = [xMin, xMax, -y, y] as Area;

            }else{
                // get y when reaching circle at xMax
                var r2 = r*r;
                var y = Math.sqrt(r2 - xMax*xMax);
                obj_ = [xMin, xMax, -y, y] as Area;
            }
            return transposeArea(obj_, DIRECTION_RIGHT, direction);
        }
        
        hidden static function reachLimits(limits as Area, aspectRatio as Decimal) as Area{
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
*/        
    }
}