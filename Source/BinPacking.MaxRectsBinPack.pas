
unit BinPacking.MaxRectsBinPack;

interface
uses
  Types,
  Math,
  System.Generics.Collections;

type
  /// <summary>
  ///   Specifies the different heuristic rules that can be used when deciding where to place a new rectangle.
  /// </summary>
  TFreeRectChoiceHeuristic = (
    /// <summary>
    /// BSSF: Positions the rectangle against the short side of a free rectangle into which it fits the best.
    /// </summary>
    frchRectBestShortSideFit,
    /// <summary>
    /// BLSF: Positions the rectangle against the long side of a free rectangle into which it fits the best.
    /// </summary>
    frchRectBestLongSideFit,
    /// <summary>
    ///   BAF: Positions the rectangle into the smallest free rect into which it fits.
    /// </summary>
    frchRectBestAreaFit,
    /// <summary>
    ///   BL: Does the Tetris placement.
    /// </summary>
    frchRectBottomLeftRule,
    /// <summary>
    ///   CP: Choosest the placement where the rectangle touches other rects as much as possible.
    /// </summary>
    frchRectContactPointRule
  );

  /// <summary>
  /// MaxRectsBinPack implements the MAXRECTS data structure and different bin packing algorithms that
	/// use this structure.
  /// </summary>
  TMaxRectsBinPack = class
  private
    binWidth : Integer;
    binHeight : Integer;
    binAllowFlip : Boolean;
    usedRectangles : TList<TRect>;
    freeRectangles : TList<TRect>;

    /// <summary>
    /// Computes the placement score for placing the given rectangle with the given method.
    /// @return
    /// </summary>
    /// <param name="score1">
    /// The primary placement score will be outputted here.
    /// </param>
    /// <param name="score2">
    /// The secondary placement score will be outputted here. This isu sed to break ties.
    /// </param>
    /// <returns>
    /// This struct identifies where the rectangle would be placed if it were placed.
    /// </returns>
    function ScoreRect(width, height : Integer; method : TFreeRectChoiceHeuristic; var  score1 : Integer; var score2 : Integer) : TRect;

    /// <summary>
    /// Places the given rectangle into the bin.
    /// </summary>
    procedure PlaceRect(const node : PRect; var dst: TList<TRect>);

    /// <summary>
    /// Computes the placement score for the -CP variant.
    /// </summary>
    function ContactPointScoreNode(x, y, width, height : Integer) : Integer;

    function FindPositionForNewNodeBottomLeft(width, height : Integer; var bestY : Integer; var bestX : Integer) : TRect;
    function FindPositionForNewNodeBestShortSideFit(width, height : Integer; var bestShortSideFit : Integer; var bestLongSideFit : Integer) : TRect;
    function FindPositionForNewNodeBestLongSideFit(width, height : Integer; var bestShortSideFit : Integer; var bestLongSideFit : Integer) : TRect;
    function FindPositionForNewNodeBestAreaFit(width, height : Integer; var bestAreaFit : Integer; var bestShortSideFit : Integer) : TRect;
    function FindPositionForNewNodeContactPoint(width, height : Integer; var bestContactScore : Integer) : TRect;

    /// <returns>
    ///   True if the free node was split.
    /// </returns>
    function SplitFreeNode(freeNode : TRect; const usedNode : PRect) : Boolean;

    /// <summary>
    ///   Goes through the free rectangle list and removes any redundant entries.
    /// </summary>
  	procedure PruneFreeList;
  public
    /// <summary>
    /// Instantiates a bin of size (0,0). Call Init to create a new bin.
    /// </summary>
    constructor Create; overload;

    /// <summary>
   	/// Instantiates a bin of the given size.
  	/// @param
    /// </summary>
    /// <param name="allowFlip">
    /// Specifies whether the packing algorithm is allowed to rotate the input rectangles by 90 degrees to consider a better placement.
    /// </param>
    constructor Create(width, height : Integer; allowFlip : Boolean = true); overload;

    /// <summary>
  	/// (Re)initializes the packer to an empty bin of width x height units. Call whenever
	  /// you need to restart with a new bin.
    /// </summary>
    procedure Init(width, height : Integer; allowFlip : Boolean = true);

    /// <summary>
  	/// Inserts the given list of rectangles in an offline/batch mode, possibly rotated.
    /// </summary>
    /// <param name="rects">
    /// The list of rectangles to insert. This vector will be destroyed in the process.
    /// </param>
    /// <param name="dst" >
    /// This list will contain the packed rectangles. The indices will not correspond to that of rects.
    /// </param>
    /// <param name="method">
    ///   The rectangle placement rule to use when packing.
    /// </param>
    procedure Insert(var rects : TList<TRect>; var dst : TList<TRect>; method : TFreeRectChoiceHeuristic); overload;


	  /// <summary>
    /// Inserts a single rectangle into the bin, possibly rotated.
    /// </summary>
  	function Insert(width, height : Integer; method : TFreeRectChoiceHeuristic) : TRect; overload;

    /// <summary>
    ///   Computes the ratio of used surface area to the total bin area.
    /// </summary>
    function Occupancy: Single;

    property Width: Integer read binWidth;
    property Height: Integer read binHeight;

    property AllowFlip: Boolean read binAllowFlip;
  end;

implementation


/// <summary>
/// Returns 0 if the two intervals i1 and i2 are disjoint, or the length of their overlap otherwise.
/// </summary>
function CommonIntervalLength(i1start, i1end, i2start, i2end : Integer) : Integer;
begin
	if (i1end < i2start) or (i2end < i1start) then
		Exit(0);
	Result := min(i1end, i2end) - max(i1start, i2start);
end;



{ TMaxRectsBinPack }

constructor TMaxRectsBinPack.Create;
begin
  binWidth := 0;
  binHeight := 0;
  usedRectangles := TList<TRect>.Create;
  freeRectangles := TList<TRect>.Create;
end;


function TMaxRectsBinPack.ContactPointScoreNode(x, y, width,height: Integer): Integer;
var
  score : Integer;
  I: Integer;
begin
	score := 0;

	if (x = 0) or (x + width = binWidth) then
		score := score + height;
	if (y = 0) or (y + height = binHeight) then
		score := score +  width;

  for I := 0 to usedRectangles.Count - 1 do
  begin
		if (usedRectangles[i].Left = x + width) or (usedRectangles[i].Left + usedRectangles[i].width = x) then
			score := score + CommonIntervalLength(usedRectangles[i].Top, usedRectangles[i].Top + usedRectangles[i].height, y, y + height);
		if (usedRectangles[i].Top = y + height) or (usedRectangles[i].Top + usedRectangles[i].height = y) then
			score := score + CommonIntervalLength(usedRectangles[i].Left, usedRectangles[i].Left + usedRectangles[i].width, x, x + width);  
  end;

	Result := score;
end;

constructor TMaxRectsBinPack.Create(width, height: Integer; allowFlip: Boolean);
begin
  Create;
	Init(width, height, allowFlip);
end;

function TMaxRectsBinPack.FindPositionForNewNodeBestAreaFit(width,
  height: Integer; var bestAreaFit, bestShortSideFit: Integer): TRect;
var
  bestNode: TRect;
  I: Integer;
  areaFit: Integer;
  leftoverHoriz: Integer;
  leftoverVert: Integer;
  shortSideFit: Integer;
begin
	bestNode := TRect.Empty;

	bestAreaFit := MaxInt;
	bestShortSideFit := MaxInt;

	for I := 0 to freeRectangles.Count - 1 do
  begin
		areaFit := freeRectangles[i].width * freeRectangles[i].height - width * height;

		// Try to place the rectangle in upright (non-flipped) orientation.
		if (freeRectangles[i].width >= width) and (freeRectangles[i].height >= height) then
    begin
			leftoverHoriz := abs(freeRectangles[i].width - width);
			leftoverVert := abs(freeRectangles[i].height - height);
			shortSideFit := min(leftoverHoriz, leftoverVert);

			if (areaFit < bestAreaFit) or ((areaFit = bestAreaFit) and (shortSideFit < bestShortSideFit)) then
      begin
				bestNode.Left := freeRectangles[i].Left;
				bestNode.Top  := freeRectangles[i].Top;
				bestNode.width := width;
				bestNode.height := height;
				bestShortSideFit := shortSideFit;
				bestAreaFit := areaFit;      
      end;          
    end;  
		if binAllowFlip and (freeRectangles[i].width >= height) and (freeRectangles[i].height >= width) then
    begin
			leftoverHoriz := abs(freeRectangles[i].width - height);
			leftoverVert := abs(freeRectangles[i].height - width);
			shortSideFit := min(leftoverHoriz, leftoverVert);

			if (areaFit < bestAreaFit) or ((areaFit = bestAreaFit) and (shortSideFit < bestShortSideFit)) then
      begin
				bestNode.Left := freeRectangles[i].Left;
				bestNode.Top := freeRectangles[i].Top;
				bestNode.width := height;
				bestNode.height := width;
				bestShortSideFit := shortSideFit;
				bestAreaFit := areaFit;      
      end;
    end;
  end;  
	Result := bestNode;
end;

function TMaxRectsBinPack.FindPositionForNewNodeBestLongSideFit(width,
  height: Integer; var bestShortSideFit, bestLongSideFit: Integer): TRect;
var
  bestNode: TRect;
  I: Integer;
  leftoverHoriz: Integer;
  leftoverVert: Integer;
  shortSideFit: Integer;
  longSideFit: Integer;
begin
	bestNode := TRect.Empty;
	bestShortSideFit := MaxInt;
	bestLongSideFit := MaxInt;

  for I := 0 to freeRectangles.Count -1 do
  begin
		// Try to place the rectangle in upright (non-flipped) orientation.
		if (freeRectangles[i].width >= width) and (freeRectangles[i].height >= height) then
    begin
			leftoverHoriz := abs(freeRectangles[i].width - width);
			leftoverVert := abs(freeRectangles[i].height - height);
			shortSideFit := Math.min(leftoverHoriz, leftoverVert);
			longSideFit := Math.max(leftoverHoriz, leftoverVert);

			if (longSideFit < bestLongSideFit) or ((longSideFit = bestLongSideFit) and (shortSideFit < bestShortSideFit)) then
      begin
				bestNode.Left := freeRectangles[i].Left;
				bestNode.Top := freeRectangles[i].Top;
				bestNode.width := width;
				bestNode.height := height;
				bestShortSideFit := shortSideFit;
				bestLongSideFit := longSideFit;
      end;
    end;
		if binAllowFlip and (freeRectangles[i].width >= height) and (freeRectangles[i].height >= width) then
    begin
			leftoverHoriz := abs(freeRectangles[i].width - height);
			leftoverVert := abs(freeRectangles[i].height - width);
			shortSideFit := Math.min(leftoverHoriz, leftoverVert);
			longSideFit := Math.max(leftoverHoriz, leftoverVert);

			if (longSideFit < bestLongSideFit) or ((longSideFit = bestLongSideFit) and (shortSideFit < bestShortSideFit)) then
      begin
				bestNode.Left := freeRectangles[i].Left;
				bestNode.Top := freeRectangles[i].Top;
				bestNode.width := height;
				bestNode.height := width;
				bestShortSideFit := shortSideFit;
				bestLongSideFit := longSideFit;
      end;
    end;
  end;

	Result := bestNode;
end;

function TMaxRectsBinPack.FindPositionForNewNodeBestShortSideFit(width,
  height: Integer; var bestShortSideFit, bestLongSideFit: Integer): TRect;
var
  bestNode: TRect;
  I: Integer;
  leftoverHoriz: Integer;
  leftoverVert: Integer;
  shortSideFit: Integer;
  longSideFit: Integer;
  flippedLeftoverHoriz: Integer;
  flippedLeftoverVert: Integer;
  flippedShortSideFit: Integer;
  flippedLongSideFit: Integer;
begin
	bestNode := TRect.Empty;
	bestShortSideFit := MaxInt;
	bestLongSideFit := MaxInt;

  for I := 0 to freeRectangles.Count -1 do
  begin
		// Try to place the rectangle in upright (non-flipped) orientation.
		if (freeRectangles[i].width >= width) and (freeRectangles[i].height >= height) then
		begin
			leftoverHoriz := Abs(freeRectangles[i].width - width);
			leftoverVert  := Abs(freeRectangles[i].height - height);
			shortSideFit  := Min(leftoverHoriz, leftoverVert);
			longSideFit   := Max(leftoverHoriz, leftoverVert);

			if (shortSideFit < bestShortSideFit) or ((shortSideFit = bestShortSideFit) and (longSideFit < bestLongSideFit)) then
      begin
				bestNode.Left := freeRectangles[i].Left;
				bestNode.Top  := freeRectangles[i].Top;
				bestNode.Width := width;
				bestNode.Height := height;
				bestShortSideFit := shortSideFit;
				bestLongSideFit := longSideFit;
      end;
    end;
  	if binAllowFlip and (freeRectangles[i].width >= height) and (freeRectangles[i].height >= width) then
    begin
			flippedLeftoverHoriz := abs(freeRectangles[i].width - height);
			flippedLeftoverVert := abs(freeRectangles[i].height - width);
			flippedShortSideFit := Math.Min(flippedLeftoverHoriz, flippedLeftoverVert);
			flippedLongSideFit := Math.Max(flippedLeftoverHoriz, flippedLeftoverVert);

			if (flippedShortSideFit < bestShortSideFit) or ((flippedShortSideFit = bestShortSideFit) and (flippedLongSideFit < bestLongSideFit)) then
      begin
				bestNode.Left := freeRectangles[i].Left;
				bestNode.Top  := freeRectangles[i].Top;
				bestNode.width := height;
				bestNode.height := width;
				bestShortSideFit := flippedShortSideFit;
				bestLongSideFit := flippedLongSideFit;      
      end;
    end;
  end;
	Result := bestNode;

end;

function TMaxRectsBinPack.FindPositionForNewNodeBottomLeft(width,
  height: Integer; var bestY, bestX: Integer): TRect;
var
  bestNode : TRect;
  I: Integer;
  topSideY: Integer;
begin
	bestNode := TRect.Empty;
	bestY := MaxInt;
	bestX := MaxInt;

  for I := 0 to freeRectangles.Count - 1 do
  begin
		// Try to place the rectangle in upright (non-flipped) orientation.
		if (freeRectangles[i].width >= width) and (freeRectangles[i].height >= height) then
    begin
			topSideY := freeRectangles[i].Top + height;
			if (topSideY < bestY) or ((topSideY = bestY) and (freeRectangles[i].Left < bestX)) then
			begin
				bestNode.Left := freeRectangles[i].Left;
				bestNode.Top  := freeRectangles[i].Top;
				bestNode.width := width;
				bestNode.height := height;
				bestY := topSideY;
				bestX := freeRectangles[i].Left;
      end;
    end;  
    if binAllowFlip and (freeRectangles[i].width >= height) and (freeRectangles[i].height >= width) then
    begin
      topSideY :=  freeRectangles[i].Top + width;    
      if (topSideY < bestY) or ((topSideY = bestY) and (freeRectangles[i].Left < bestX)) then
      begin
        bestNode.left := freeRectangles[i].Left;
        bestNode.Top  := freeRectangles[i].Top;
        bestNode.width := height;
        bestNode.height := width;
        bestY := topSideY;
        bestX := freeRectangles[i].Left;        
      end;
    end;      
  end;

	Result := bestNode;

end;

function TMaxRectsBinPack.FindPositionForNewNodeContactPoint(width,
  height: Integer; var bestContactScore: Integer): TRect;
var
  bestNode: TRect;
  I: Integer;
  score: Integer;
begin
	bestNode := TRect.Empty;
	bestContactScore := -1;

  for I := 0 to freeRectangles.Count - 1 do
  begin
		// Try to place the rectangle in upright (non-flipped) orientation.
		if (freeRectangles[i].width >= width) and (freeRectangles[i].height >= height) then
    begin
			score := ContactPointScoreNode(freeRectangles[i].Left, freeRectangles[i].Top, width, height);
			if (score > bestContactScore) then
			begin
				bestNode.Left := freeRectangles[i].Left;
				bestNode.Top := freeRectangles[i].Top;
				bestNode.width := width;
				bestNode.height := height;
				bestContactScore := score;
      end;
    end;
		if (freeRectangles[i].width >= height) and (freeRectangles[i].height >= width) then
    begin
			score := ContactPointScoreNode(freeRectangles[i].Left, freeRectangles[i].Top, height, width);
			if (score > bestContactScore) then
      begin
				bestNode.Left := freeRectangles[i].Left;
				bestNode.Top := freeRectangles[i].Top;
				bestNode.width := height;
				bestNode.height := width;
				bestContactScore := score;
      end;
    end;
  end;
	Result := bestNode;
end;

procedure TMaxRectsBinPack.Init(width, height: Integer; allowFlip: Boolean);
var
  rect : TRect;
begin
	binAllowFlip := allowFlip;
	binWidth := width;
	binHeight := height;

	rect := TRect.Create(0, 0, width, height);

	usedRectangles.Clear;
	freeRectangles.Clear;
	freeRectangles.Add(rect)
end;

function TMaxRectsBinPack.Insert(width, height: Integer; method: TFreeRectChoiceHeuristic): TRect;
var
  newNode : TRect;
  score1 : Integer;
  score2 : Integer;
  numRectanglesToProcess : Integer;
  I : Integer;
begin
	// Unused in this function. We don't need to know the score after finding the position.
  score1 := MaxInt;
  score2 := MaxInt;
	case method of
    frchRectBestShortSideFit :
      newNode := FindPositionForNewNodeBestShortSideFit(width, height, score1, score2);
    frchRectBottomLeftRule :
      newNode := FindPositionForNewNodeBottomLeft(width, height, score1, score2);
    frchRectContactPointRule :
      newNode := FindPositionForNewNodeContactPoint(width, height, score1);
    frchRectBestLongSideFit :
      newNode := FindPositionForNewNodeBestLongSideFit(width, height, score1, score2);
    else newNode := FindPositionForNewNodeBestAreaFit(width, height, score1, score2);
  end;

	if newNode.Height = 0 then
		Exit(newNode);

	numRectanglesToProcess := freeRectangles.Count;
  I := 0;
  While I < numRectanglesToProcess do
  begin
    if SplitFreeNode(freeRectangles[I], @newNode) then
    begin
      freeRectangles.Remove(freeRectangles[I]);
      Dec(I);
      Dec(numRectanglesToProcess);
    end;
    Inc(I);
  end;

	PruneFreeList();

	usedRectangles.Add(newNode);
	Result := newNode;
end;

function TMaxRectsBinPack.Occupancy: Single;
var 
  usedSurfaceArea : Cardinal;
  I: Integer;
begin
	usedSurfaceArea := 0;
  
  for I := 0 to usedRectangles.Count - 1 do
    usedSurfaceArea := usedSurfaceArea + (usedRectangles[i].width * usedRectangles[i].height);		

	Result := usedSurfaceArea / (binWidth * binHeight);
end;

procedure TMaxRectsBinPack.PlaceRect(const node: PRect; var dst: TList<TRect>);
var
  numRectanglesToProcess: Integer;
  I: Integer;
begin
	numRectanglesToProcess := freeRectangles.Count;
  I := 0;
  while I < numRectanglesToProcess do
  begin
		if SplitFreeNode(freeRectangles[I], node) then
    begin
			freeRectangles.Remove(freeRectangles[I]);
      Dec(I);
      Dec(numRectanglesToProcess)    
    end;
    Inc(I);  
  end;

	PruneFreeList();

	usedRectangles.Add(node^);
  dst.Add(node^)
end;

procedure TMaxRectsBinPack.PruneFreeList;
var
  I: Integer;
  J: Integer;
begin
	///  Would be nice to do something like this, to avoid a Theta(n^2) loop through each pair.
	///  But unfortunately it doesn't quite cut it, since we also want to detect containment.
	///  Perhaps there's another way to do this faster than Theta(n^2).

	/// Go through each pair and remove any rectangle that is redundant.
  I := 0;
  while I < freeRectangles.Count do
  begin
    J := I+1;
    while J < freeRectangles.Count do
    begin                                                            
      if freeRectangles[J].Contains(freeRectangles[I]) then
      begin
        freeRectangles.Remove(freeRectangles[I]);
        Dec(I);
        Break;
      end;
      if freeRectangles[I].Contains(freeRectangles[J]) then
      begin
        freeRectangles.Remove(freeRectangles[J]);      
        Dec(J);
      end;
      Inc(J);
    end;
    Inc(I);
  end;
end;

function TMaxRectsBinPack.ScoreRect(width, height: Integer;
  method: TFreeRectChoiceHeuristic; var score1, score2: Integer): TRect;
var
  newNode : TRect;
begin
	score1 := MaxInt;
	score2 := MaxInt;
	case method of
    frchRectBestShortSideFit: newNode := FindPositionForNewNodeBestShortSideFit(width, height, score1, score2);
    frchRectBestLongSideFit: newNode := FindPositionForNewNodeBestLongSideFit(width, height, score1, score2);
    frchRectBestAreaFit: newNode := FindPositionForNewNodeBestAreaFit(width, height, score1, score2);
    frchRectBottomLeftRule: newNode := FindPositionForNewNodeBottomLeft(width, height, score1, score2);
    frchRectContactPointRule:
    begin
      newNode := FindPositionForNewNodeContactPoint(width, height, score1);
      score1 := -score1; // Reverse since we are minimizing, but for contact point score bigger is better.
    end;
  end;

	// Cannot fit the current rectangle.
	if newNode.height = 0 then
  begin
    score1 := MaxInt;
    score2 := MaxInt;    
  end;

	Result := newNode;
end;

function TMaxRectsBinPack.SplitFreeNode(freeNode: TRect; const usedNode: PRect): Boolean;
var
  newNode: TRect;
begin
	// Test with SAT if the rectangles even intersect.
	if (usedNode.Left >= freeNode.Left + freeNode.width) or (usedNode.Left + usedNode.width <= freeNode.Left) or
		 (usedNode.Top >= freeNode.Top + freeNode.height) or (usedNode.Top + usedNode.height <= freeNode.Top) then
		Exit(false);

	if (usedNode.Left < freeNode.Left + freeNode.width) and (usedNode.Left + usedNode.width > freeNode.Left) then
  begin
  	// New node at the top side of the used node.
		if (usedNode.Top > freeNode.Top) and (usedNode.TOp < freeNode.Top + freeNode.height) then
		begin
			newNode := freeNode;
			newNode.height := usedNode.Top - newNode.Top;
			freeRectangles.Add(newNode);
		end;

		// New node at the bottom side of the used node.
		if (usedNode.Top + usedNode.height < freeNode.Top + freeNode.height) then
		begin
			newNode := freeNode;
			newNode.Top := usedNode.Top + usedNode.height;
			newNode.Height := freeNode.Top + freeNode.height - (usedNode.Top + usedNode.height);
			freeRectangles.Add(newNode);
    end;
  end;

	if (usedNode.Top < freeNode.Top + freeNode.height) and (usedNode.Top + usedNode.height > freeNode.Top) then
  begin
 		// New node at the left side of the used node.
		if (usedNode.Left > freeNode.Left) and (usedNode.Left < freeNode.Left + freeNode.width) then
    begin
			newNode := freeNode;
			newNode.Width := usedNode.Left - newNode.Left;
			freeRectangles.Add(newNode);
    end;

		// New node at the right side of the used node.
		if (usedNode.Left + usedNode.width < freeNode.Left + freeNode.width) then
    begin
			newNode := freeNode;
			newNode.Left := usedNode.Left + usedNode.width;
			newNode.Width := freeNode.Left + freeNode.width - (usedNode.Left + usedNode.width);
			freeRectangles.Add(newNode);
    end;
  end;

	Result := true;
end;

procedure TMaxRectsBinPack.Insert(var rects, dst: TList<TRect>; method: TFreeRectChoiceHeuristic);
var
  score1 : Integer;
  score2 : Integer;
  bestRectIndex: Integer;
  bestNode : TRect;
  I: Integer;
  bestScore1: Integer;
  bestScore2: Integer;
  newNode: TRect;
begin
	dst.Clear;

	while(rects.Count > 0) do
  begin
    bestScore1 := MaxInt;
    bestScore2 := MaxInt;
    bestRectIndex := -1;
    for I := 0 to rects.Count-1 do
    begin
      score1 := MaxInt;
      score2 := MaxInt;
      newNode := ScoreRect(rects[i].width, rects[i].height, method, score1, score2); 
			if (score1 < bestScore1) or ((score1 = bestScore1) and (score2 < bestScore2)) then
      begin
        bestScore1 := score1;
				bestScore2 := score2;
				bestNode := newNode;
				bestRectIndex := I;  
      end;
    end;
    if bestRectIndex = -1 then
      Exit;

    PlaceRect(@bestNode, dst);
    rects.Remove(rects[bestRectIndex]);
  end;
end;

end.
