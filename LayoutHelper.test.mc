import Toybox.Test;
using Toybox.System;
import Toybox.WatchUi;
using Toybox.Math;
import Toybox.Lang;
import MyLayoutHelper;
using MyMath;

(:test)
function layoutHelper_fitAreaWithRatio(logger as Logger) as Boolean{
	var counter = 0;
	var deviceSettings = System.getDeviceSettings();
	System.println(Lang.format("screenShape: $1$", [deviceSettings.screenShape]));
	if(deviceSettings.screenShape == System.SCREEN_SHAPE_ROUND){
		// For now only round screens are supported
		var helper = new MyLayoutHelper.RoundScreenHelper({});

		var diameter = deviceSettings.screenWidth;
		var radius = diameter/2;
		System.println(Lang.format("screenSize: $1$", [diameter]));
		var stepSize = diameter / 4;

		for(var ratio = 0.5f; ratio <= 2.0; ratio += 0.25){
		// if(ratio != 2.0f) { continue; }
			for(var y=0; y < diameter; y+=stepSize){
				// if(y != 0) { continue; }
				for(var x=0; x < diameter; x+=stepSize){
					// if(x != 0) { continue; }
					for(var h=stepSize; y+h <= diameter; h+=stepSize){
						// if(h != 195) { continue; }
						for(var w=stepSize; x+w <= diameter; w+=stepSize){
							// if(w != 130) { continue; }
							counter++;

							// check valid
							var errorMessages = [] as Array<String>;
							var infoMessages = ["#"+counter.toString()] as Array<String>;
							helper.setLimits(x, x+w, y, y+h);

							var shape = new WatchUi.Drawable({ :width => 10*ratio, :height => 10 });
							helper.resizeToMax(shape, true, 0);

							// limits:
							var limits = helper.getLimits();
							for(var i=0; i<limits.size(); i++){
								limits[i] -= radius;
							}
							infoMessages.add(Lang.format("Limits: x [$1$..$2$], y [$3$..$4$]", limits));

							var xMin = limits[0];
							var xMax = limits[1];
							var yMin = limits[2];
							var yMax = limits[3];

							// result:
							var xMin_ = shape.locX - radius;
							var xMax_ = xMin_ + shape.width;
							var yMin_ = shape.locY - radius;
							var yMax_ = yMin_ + shape.height;
							var ratio_ = 1f*(xMax_ - xMin_)/(yMax_ - yMin_);

							infoMessages.add(Lang.format("Result: x [$1$..$2$], y [$3$..$4$], Ratio $5$", [
								xMin_,
								xMax_,
								yMin_,
								yMax_,
								ratio_,
							]));


							// check ratio
							if(MyMath.abs((ratio_-ratio)/ratio) > 0.05){ errorMessages.add("Wrong Ratio"); }

							// check within given boundaries
							if(xMin_ < xMin){ errorMessages.add("Outside left boundaries"); }
							if(yMax_ > yMax){ errorMessages.add("Outside top boundaries"); }
							if(xMax_ > xMax){ errorMessages.add("Outside right boundaries"); }
							if(yMin_ < yMin){ errorMessages.add("Outside bottom boundaries"); }

							// check within circle
							var xMin2 = xMin_ * xMin_;
							var xMax2 = xMax_ * xMax_;
							var yMin2 = yMin_ * yMin_;
							var yMax2 = yMax_ * yMax_;

							// check if boundaries are ok
							var radius_top_right    = Math.sqrt(xMax2 + yMax2);
							var radius_top_left     = Math.sqrt(xMin2 + yMax2);
							var radius_bottom_left  = Math.sqrt(xMin2 + yMin2);
							var radius_bottom_right = Math.sqrt(xMax2 + yMin2);

							if(radius_top_right    > radius + 1){ errorMessages.add("Outside circle (top-right)"); }
							if(radius_top_left     > radius + 1){ errorMessages.add("Outside circle (top-left)"); }
							if(radius_bottom_left  > radius + 1){ errorMessages.add("Outside circle (bottom-left)"); }
							if(radius_bottom_right > radius + 1){ errorMessages.add("Outside circle (bottom-right)"); }

							// check if the maximum space is used
							var quality = 0f;
/*							
							if(MyMath.abs(xMax - xMax_) <= 1){ quality += 1.25; }
							if(MyMath.abs(xMin - xMin_) <= 1){ quality += 1.25; }
							if(MyMath.abs(yMax - yMax_) <= 1){ quality += 1.25; }
							if(MyMath.abs(yMin - yMin_) <= 1){ quality += 1.25; }
							if(MyMath.abs(radius_top_right    - radius) <= 2){ quality += 1.5; }
							if(MyMath.abs(radius_top_left     - radius) <= 2){ quality += 1.5; }
							if(MyMath.abs(radius_bottom_left  - radius) <= 2){ quality += 1.5; }
							if(MyMath.abs(radius_bottom_right - radius) <= 2){ quality += 1.5; }
*/
							var corners = ["top-right", "top-left", "bottom-left", "bottom-right"] as Array<String>;
							for(var i=0; i<corners.size(); i++){
								var corner = corners[i];
								var onVerticalBoundary = (i==0 || i==3)
									? (xMax == xMax_)
									: (xMin == xMin_);
								var onHorizontalBoundary = (i==0 || i==1)
									? (yMax == yMax_)
									: (yMin == yMin_);
								
								var onCircleEdge = false;
								if(i==0){
									onCircleEdge = (MyMath.abs(radius_top_right    - radius) <= 2);
								}else if(i==1){
									onCircleEdge = (MyMath.abs(radius_top_left     - radius) <= 2);
								}else if(i==2){
									onCircleEdge = (MyMath.abs(radius_bottom_left  - radius) <= 2);
								}else if(i==3){
									onCircleEdge = (MyMath.abs(radius_bottom_right - radius) <= 2);
								}

								if(onVerticalBoundary && onHorizontalBoundary){
									infoMessages.add(corner + ": on boundary corner");
									quality += 1.2;
								}else if(onVerticalBoundary){
									if(onCircleEdge){
										infoMessages.add(corner + ": on vertical boundary and circle");
										quality += 1.1;
									}else{
										infoMessages.add(corner + ": ONLY on vertical boundary");
										quality += 1;
									}
								}else if(onHorizontalBoundary){
									if(onCircleEdge){
										infoMessages.add(corner + ": on horizontal boundary and circle");
										quality += 1.1;
									}else{
										infoMessages.add(corner + ": ONLY on horizontal boundary");
										quality += 1;
									}
								}else{
									if(onCircleEdge){
										infoMessages.add(corner + ": on circle");
										quality += 1;
									}else{
										errorMessages.add(corner + ": NOT ON CIRCLE OR BOUNDARY!!!");
									}
								}
							}
							if(quality < 4){
								errorMessages.add("The size of the area should be increased (quality="+quality+")");
							}

							if(errorMessages.size() > 0){
								// collect additional info
								for(var i=0; i < helper.debugInfo.size(); i++){
									System.println(helper.debugInfo[i]);
								}
								for(var i=0; i < infoMessages.size(); i++){
									System.println(infoMessages[i]);
								}

								for(var i=0; i < errorMessages.size(); i++){
									logger.error(errorMessages[i]);
								}

								return false;
							}
						}
					}
				}
			}
		}
	}else{
		logger.warning("For now only Rounded screens are tested");
	}
	return true;
}

(:test)
function layoutHelper_Alignment(logger as Logger) as Boolean{
	var deviceSettings = System.getDeviceSettings();
	var diameter = deviceSettings.screenWidth;
	var r = diameter / 2;
	var helper = new MyLayoutHelper.RoundScreenHelper({});

	// 4 different boundaries
	var boundariesList = [
		[0             , diameter,		0             ,       diameter],
		[0             , 0.6 * diameter, 0             ,       diameter],
		[0             , 0.7 * diameter, 0             , 0.3 * diameter],
		[0.2 * diameter, 0.6 * diameter, 0.1 * diameter, 0.6 * diameter],
	] as Array< Array<Numeric> >;
	// 2 different shapes [width, height]
	var shapeList = [
		[diameter/2, diameter/5] as Array<Numeric>,
		[diameter/7, diameter/3] as Array<Numeric>,
	] as Array< Array<Numeric> >;
	// 8 alignments
	var alignmentList = [
		MyLayoutHelper.ALIGN_TOP,
//		MyLayoutHelper.ALIGN_TOP|MyLayoutHelper.ALIGN_RIGHT,
		MyLayoutHelper.ALIGN_RIGHT,
//		MyLayoutHelper.ALIGN_BOTTOM|MyLayoutHelper.ALIGN_RIGHT,
		MyLayoutHelper.ALIGN_BOTTOM,
//		MyLayoutHelper.ALIGN_BOTTOM|MyLayoutHelper.ALIGN_LEFT,
		MyLayoutHelper.ALIGN_LEFT,
//		MyLayoutHelper.ALIGN_TOP|MyLayoutHelper.ALIGN_LEFT,
	] as Array<Alignment|Number>;

	for(var b=0; b<boundariesList.size(); b++){
		var boundaries = boundariesList[b];
		for(var s=0; s<shapeList.size(); s++){
			var widthAndHeight = shapeList[s];
			for(var a=0; a<alignmentList.size(); a++){
				var shape = new WatchUi.Drawable({
					:width => widthAndHeight[0], 
					:height => widthAndHeight[1],
				});
				var alignment = alignmentList[a];
				var errorMessages = [] as Array<String>;
				var infoMessages = [] as Array<String>;

				infoMessages.add(Lang.format("Boundaries: x,y = $1$,$2$ w,h = $3$,$4$", [boundaries[0], boundaries[2], boundaries[1]-boundaries[0], boundaries[3]-boundaries[2]]));
				infoMessages.add(Lang.format("Shape: x,y = $1$,$2$ w,h = $3$,$4$", [shape.locX, shape.locY, shape.width, shape.height]));
				infoMessages.add(Lang.format("Alignment: $1$", [alignment]));

				helper.setLimits(boundaries[0],boundaries[1],boundaries[2],boundaries[3]);
				try{
					helper.align(shape, alignment);
				}catch(ex instanceof Lang.Exception){
					System.println(ex.getErrorMessage());
				}

				// get the relevant corner(s) for the alignment
				var corners = [] as Array;
				if(alignment == MyLayoutHelper.ALIGN_TOP){
					corners.add([shape.locX, shape.locY]);
					corners.add([shape.locX + shape.width, shape.locY]);
				}else if(alignment == MyLayoutHelper.ALIGN_RIGHT){
					corners.add([shape.locX + shape.width, shape.locY]);
					corners.add([shape.locX + shape.width, shape.locY + shape.height]);
				}else if(alignment == MyLayoutHelper.ALIGN_BOTTOM){
					corners.add([shape.locX, shape.locY + shape.height]);
					corners.add([shape.locX + shape.width, shape.locY + shape.height]);
				}else if(alignment == MyLayoutHelper.ALIGN_LEFT){
					corners.add([shape.locX, shape.locY]);
					corners.add([shape.locX, shape.locY + shape.height]);
				}else if(alignment == (MyLayoutHelper.ALIGN_TOP|MyLayoutHelper.ALIGN_LEFT)){
					corners.add([shape.locX, shape.locY]);
				}else if(alignment == (MyLayoutHelper.ALIGN_TOP|MyLayoutHelper.ALIGN_RIGHT)){
					corners.add([shape.locX + shape.width, shape.locY]);
				}else if(alignment == (MyLayoutHelper.ALIGN_BOTTOM|MyLayoutHelper.ALIGN_RIGHT)){
					corners.add([shape.locX + shape.width, shape.locY + shape.height]);
				}else if(alignment == (MyLayoutHelper.ALIGN_BOTTOM|MyLayoutHelper.ALIGN_LEFT)){
					corners.add([shape.locX, shape.locY + shape.height]);
				}

				// check if the size of the shape is to big to align within the circle
				var shapeToBig = false;
				if(corners.size() == 2){
					var width = corners[1][0] - corners[0][0];
					var height = corners[1][1] - corners[0][1];
					if(width > (boundaries[1]-boundaries[0])){
						infoMessages.add("The width of the shape exceeds the boundaries");
						shapeToBig = true;
					}
					if(height > (boundaries[3]-boundaries[2])){
						infoMessages.add("The height of the shape exceeds the boundaries");
						shapeToBig = true;
					}
				}

				// see if the corners are on a boundary or circle edge
				for(var c=0; c<corners.size(); c++){
					var x = corners[c][0] as Numeric;
					var y = corners[c][1] as Numeric;

					var countOnBoundary = 0;
					var onCircle = false;

					// on a boundary
					if(boundaries[0] == x){ countOnBoundary++; }
					if(boundaries[1] == x){ countOnBoundary++; }
					if(boundaries[2] == y){ countOnBoundary++; }
					if(boundaries[3] == y){ countOnBoundary++; }

					infoMessages.add(Lang.format("corner$1$ ($2$, $3$): has $4$ points on a boundary", [c, x, y, countOnBoundary]));

					if(!shapeToBig){

						// on circle edge or outside circle
						var fromCenterHorizontal = x - r;
						var fromCenterVertical = y - r;
						var fromCenter = Math.sqrt(fromCenterHorizontal*fromCenterHorizontal + fromCenterVertical*fromCenterVertical);
						infoMessages.add(Lang.format("corner$1$ ($2$, $3$): radius from center: $4$", [c, x, y, fromCenter]));
						if(fromCenter > r + 1){
							// outside circle
							errorMessages.add(Lang.format("corner$1$: Outside circle!", [c, x, y, fromCenter]));
						}else if(fromCenter >= r - 1){
							// on circle
							onCircle = true;
							infoMessages.add(Lang.format("corner$1$): On the edge of the circle", [c, x, y]));
						}
					}

					// Now determine if the shape is aligned properly
					// each relevant corner should touch boundary or corner
					if(countOnBoundary == 0 && !onCircle){
						errorMessages.add(Lang.format("corner$1$ ($2$, $3$): is not on circle edge or a boundary", [c, x, y]));
					}
				}
				
				// final verdict
				if(errorMessages.size() > 0){
					// print info
					for(var i=0; i<infoMessages.size(); i++){
						System.println(infoMessages[i]);
					}

					// print errors
					for(var i=0; i<errorMessages.size(); i++){
						logger.error(errorMessages[i]);
					}
					return false;
				}
			}
		}
	}
	return true;
}