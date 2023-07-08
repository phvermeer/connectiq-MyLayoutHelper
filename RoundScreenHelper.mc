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
            DIRECTION_UP = 1,
            DIRECTION_LEFT = 2,
            DIRECTION_DOWN = 4,
            DIRECTION_RIGHT = 8,
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
                nrOfQuadrantsToRotate = 4 - nrOfQuadrantsToRotate;
                var objAligned = rotateArea(objRotated, nrOfQuadrantsToRotate);

                // get the movement
                dx = objAligned[0] - obj[0];
                dy = objAligned[2] - obj[2];

            }

            shape.locX += dx;
            shape.locY += dy;
        }


        function resizeToMax(shape as IDrawable, keepAspectRatio as Boolean) as Void{
            // resize object to fit within outer limits

            var aspectRatio = shape.width.toFloat()/shape.height;
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

            // create a set of quadrants where the circle edge can be reached
            for(var q=QUADRANT_TOP_RIGHT; q<=QUADRANT_BOTTOM_RIGHT; q*=2){
                var x = (q==QUADRANT_TOP_RIGHT || q==QUADRANT_BOTTOM_RIGHT) ? xMax : -xMin;
                var y = (q==QUADRANT_TOP_LEFT || q==QUADRANT_TOP_RIGHT) ? yMax : -yMin;
 
                if((x*x + y*y > r2) && (x>0) && (y>0)){
                    quadrants += q;
                }
            }

            // no circle edges => resize to limits
            if(quadrants == 0){
                var dx = 0;
                var dy = 0;
                if(keepAspectRatio){
                    var wL = xMax-xMin;
                    var hL = yMax-yMin;
                    var ratioL = wL/hL;
                    if(ratioL >= aspectRatio){
                        var h = hL;
                        var w = h*aspectRatio;
                        dx = (wL - w)/2;
                    }else{
                        var w = hL;
                        var h = w/aspectRatio;
                        dy = (hL - h)/2;
                    }
                }
                obj = [
                    dx + xMin, 
                    -dx + xMax,
                    dy + yMin, 
                    -dy + yMax
                ] as Area;
                applyArea(obj, shape);
                return;
            }

			// check if the circle edge can be reached with all 4 corners
   			var quadrantCount = MyMath.countBitsHigh(quadrants);

			if(quadrantCount == 4){
				reachCircleEdge_4Points(obj, aspectRatio);

				// check boundaries
				var exceeded_quadrants = checkLimits(obj);
				if(exceeded_quadrants != 0){
					//quadrants &= ~exceeded_quadrants;
				}else{
					applyArea(obj, shape);
					return;
				}
			}

			if(quadrantCount > 1){
				// No sollution yet......
				// check if the circle edge can be reached with 2 corners
				// collect in which directions the circle can be reached

                // loop through all quadrants to collect possible direction
                //  Q1 (top-right)    = 1      up      = 1
                //  Q2 (top-left)     = 2      left    = 2
                //  Q3 (bottom-left)  = 4      down    = 4
                //  Q4 (bottom-right) = 8      right   = 8
                var directions = 0;
				if((quadrants & QUADRANT_TOP_RIGHT) > 0){
					if((quadrants & QUADRANT_TOP_LEFT) > 0){
						directions |= DIRECTION_UP;
					}
					if((quadrants & QUADRANT_BOTTOM_RIGHT) > 0){
						directions |= DIRECTION_RIGHT;
					}
				}
				if((quadrants & QUADRANT_BOTTOM_LEFT) > 0){
					if((quadrants & QUADRANT_BOTTOM_RIGHT) > 0){
						directions |= BOTTOM;
					}
					if((quadrants & QUADRANT_TOP_LEFT) > 0){
						directions |= LEFT;
					}
				}

				// Choose direction from opposite directions
				if(directions & (LEFT|RIGHT) == (LEFT|RIGHT)){
					if(xMin + xMax > 0){
						directions &= ~LEFT;
					}else{
						directions &= ~RIGHT;
					}
				}
				if(directions & (TOP|BOTTOM) == (TOP|BOTTOM)){
					if(yMin + yMax > 0){
						directions &= ~BOTTOM;
					}else{
						directions &= ~TOP;
					}
				}

				var directionsArray = MyMath.getBitValues(directions);
				for(var i=0; i<directionsArray.size(); i++){
					var direction = directionsArray[i] as Direction;
					reachCircleEdge_2Points(obj, aspectRatio, direction);

					// check boundaries
					var exceeded_quadrants = checkLimits(obj);
					if(exceeded_quadrants > 0){
						// quadrants &= ~exceeded_quadrants;
					}else{
						applyArea(obj, shape);
						return;
					}
				}
			}

			if(quadrants > 0){
				// No sollution yet......
				// Check if edge of circle can be reached at 1 corner

				// reduce quadrants (remove quadrants with smallest space within boundaries)
				var quadrant = quadrants;
				quadrantCount = MyMath.countBitsHigh(quadrant);
				if(quadrantCount > 1){
					var removed_quadrants = 0;
					if(quadrants & QUADRANT_TOP_RIGHT > 0){
						if(quadrants & QUADRANT_TOP_LEFT > 0){
							if(xMin + xMax > 0){
								removed_quadrants |= QUADRANT_TOP_LEFT;
							}else{
								removed_quadrants |= QUADRANT_TOP_RIGHT;
							}
						}
						if(quadrants & QUADRANT_BOTTOM_RIGHT > 0){
							if(yMin + yMax > 0){
								removed_quadrants |= QUADRANT_BOTTOM_RIGHT;
							}else{
								removed_quadrants |= QUADRANT_TOP_RIGHT;
							}
						}
					}
					if(quadrants & QUADRANT_BOTTOM_LEFT > 0){
						if(quadrants & QUADRANT_BOTTOM_RIGHT > 0){
							if(xMin + xMax > 0){
								removed_quadrants |= QUADRANT_BOTTOM_LEFT;
							}else{
								removed_quadrants |= QUADRANT_BOTTOM_RIGHT;
							}
						}
						if(quadrants & QUADRANT_TOP_LEFT > 0){
							if(yMin + yMax > 0){
								removed_quadrants |= QUADRANT_BOTTOM_LEFT;
							}else{
								removed_quadrants |= QUADRANT_TOP_LEFT;
							}
						}
					}
					quadrant &= ~removed_quadrants;
				}
				reachCircleEdge_1Point(obj, aspectRatio, quadrant as Quadrant);

				// check boundaries
				var exceeded_quadrants = checkLimits(obj);
				if(exceeded_quadrants == 0){
                    applyArea(obj, shape);
					return;
				}
			}

			if(quadrants > 0){
				// shrink to fit within boundaries (ratio only to determine shrink and grow direction)
				if(shape != null){
					shrinkAndResize(obj, quadrants);
					applyArea(obj, shape);
					return;
				}
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
        hidden function flipArea(area as Area, horizontal as Boolean) as Area{
            if(horizontal){
                return [-area[1], -area[0], area[2], area[3]] as Area;
            }else{
                return [area[0], area[1], -area[3], -area[2]] as Area;
            }
        }
        hidden function checkLimits(area as Area) as Quadrant|Number{
            // return the quadrants that are exceeded
            var exceededQuadrants = 0;
            for(var q=QUADRANT_TOP_RIGHT; q<QUADRANT_BOTTOM_RIGHT; q*=2){
                var x = (q==QUADRANT_TOP_RIGHT || q==QUADRANT_BOTTOM_RIGHT) ? area[1] : -area[0];
                var y = (q==QUADRANT_TOP_RIGHT || q==QUADRANT_TOP_LEFT) ? area[3] : -area[2];
                var xL = (q==QUADRANT_TOP_RIGHT || q==QUADRANT_BOTTOM_RIGHT) ? limits[1] : -limits[0];
                var yL = (q==QUADRANT_TOP_RIGHT || q==QUADRANT_TOP_LEFT) ? limits[3] : -limits[2];

                if(x > xL || y > yL){
                    exceededQuadrants |= q;
                }
            }
            return exceededQuadrants;
        }

        // align functions
        hidden function reachCircleEdge_4Points(obj as Area, aspectRatio as Decimal) as Void{

        }

        hidden function reachCircleEdge_2Points(obj as Area, aspectRatio as Decimal, direction as Direction|Number) as Void{

        }

        hidden function reachCircleEdge_1Point(obj as Area, aspectRatio as Decimal, quadrant as Quadrant)as Void{

        }

        hidden function shrinkAndResize(obj as Area, quadrants as Quadrant|Number) as Void{
			var xMin = limits[0];
			var xMax = limits[1];
			var yMin = limits[2];
			var yMax = limits[3];

			// first shrink and then determine the resize direction(s)
			var directions = 0;
			if(obj[0] < xMin){
				obj[0] = xMin;
				directions |= DIRECTION_UP|DIRECTION_DOWN;
			}
			if(obj[1] > xMax){
				obj[1]= xMax;
				directions |= DIRECTION_UP|DIRECTION_DOWN;
			}
			if(obj[3] > yMax){
                obj[3] = yMax;
				directions |= DIRECTION_LEFT|DIRECTION_RIGHT;
			}
			if(obj[2] < yMin){
				obj[2] = yMin;
				directions |= DIRECTION_LEFT|DIRECTION_RIGHT;
			}

			// check which resizing direction is required
			var include_directions = 0;
			if(quadrants & (QUADRANT_TOP_LEFT|QUADRANT_TOP_RIGHT) > 0){ include_directions |= DIRECTION_UP; }
			if(quadrants & (QUADRANT_TOP_RIGHT|QUADRANT_BOTTOM_RIGHT) > 0){ include_directions |= DIRECTION_RIGHT; }
			if(quadrants & (QUADRANT_BOTTOM_LEFT|QUADRANT_BOTTOM_RIGHT) > 0){ include_directions |= DIRECTION_DOWN; }
			if(quadrants & (QUADRANT_TOP_LEFT|QUADRANT_BOTTOM_LEFT) > 0){ include_directions |= DIRECTION_LEFT; }
			directions &= include_directions;

			// Do the resizing till the circle edge
			var r2 = r * r;
			var x = MyMath.max([-xMin, xMax] as Array<Numeric>);
			var y = MyMath.max([-yMin, yMax] as Array<Numeric>);

			if(directions & DIRECTION_UP > 0)   { obj[3] = Math.sqrt(r2 - x*x); }
			if(directions & DIRECTION_LEFT > 0) { obj[0] = -Math.sqrt(r2 - y*y); }
			if(directions & DIRECTION_DOWN > 0) { obj[2] = -Math.sqrt(r2 - x*x); }
			if(directions & DIRECTION_RIGHT > 0){ obj[1] = Math.sqrt(r2 - y*y); }
		}

    }
}