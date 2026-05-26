% Check and process Antarctica_Boundary for Elmer mesh generation
% Author: Yu Wang
% Date: October 2022, at IMAS
% Updated in April 2026 for Antarctica boundary
% -Infinite Progress-
%
% Input:  Antarctica_Boundary_xy.csv (exported from GeoPackage with x,y)
% Output: Antarctica_Boundary_clean.csv (sequential indices, no duplicates)
%
% Coordinate system: EPSG:3031 (Antarctic Polar Stereographic)

clc; clear; close all;

%% Step 1: Read the boundary CSV with x,y coordinates

data = readtable('Antarctica_Boundary_xy.csv');
fprintf('=== Antarctica Boundary Check ===\n');
fprintf('Total points loaded: %d\n', height(data));
fprintf('Columns: %s\n', strjoin(data.Properties.VariableNames, ', '));

x = data.x;
y = data.y;
vidx = data.vertex_index;

%% Step 2: Check vertex_index continuity

fprintf('\n--- Continuity Check ---\n');

% Check if vertex_index is monotonically increasing
isMonotonic = all(diff(vidx) > 0);
fprintf('Vertex index monotonically increasing: %s\n', string(isMonotonic));

% Find gaps in vertex_index
expectedIdx = (vidx(1) : vidx(end))';
missingIdx = setdiff(expectedIdx, vidx);
fprintf('Vertex index range: [%d, %d]\n', vidx(1), vidx(end));
fprintf('Expected points (no gaps): %d\n', length(expectedIdx));
fprintf('Actual points: %d\n', length(vidx));
fprintf('Missing indices (gaps): %d\n', length(missingIdx));

if ~isempty(missingIdx)
    % Find contiguous gap segments
    gapDiff = diff(missingIdx);
    gapStarts = [1; find(gapDiff > 1) + 1];
    gapEnds   = [find(gapDiff > 1); length(missingIdx)];
    nGaps = length(gapStarts);
    fprintf('Number of gap segments: %d\n', nGaps);
    fprintf('First 10 gap segments:\n');
    for i = 1:min(10, nGaps)
        gStart = missingIdx(gapStarts(i));
        gEnd   = missingIdx(gapEnds(i));
        gLen   = gEnd - gStart + 1;
        fprintf('  Gap: index %d to %d (%d missing points)\n', gStart, gEnd, gLen);
    end
    if nGaps > 10
        fprintf('  ... and %d more gap segments\n', nGaps - 10);
    end
end

%% Step 3: Check for duplicate coordinate points

fprintf('\n--- Duplicate Points Check ---\n');

coords = [x, y];
[uniqueCoords, uniqueIdx, ~] = unique(coords, 'rows', 'stable');
nTotal = size(coords, 1);
nUnique = size(uniqueCoords, 1);
nDuplicates = nTotal - nUnique;

fprintf('Total points: %d\n', nTotal);
fprintf('Unique (x,y) pairs: %d\n', nUnique);
fprintf('Duplicate points: %d\n', nDuplicates);

% Find and report duplicate locations
if nDuplicates > 0
    duplicateRows = setdiff(1:nTotal, uniqueIdx);
    fprintf('Duplicate points found at row indices:\n');
    for i = 1:length(duplicateRows)
        dRow = duplicateRows(i);
        dx = x(dRow);
        dy = y(dRow);
        % Find all rows with same coordinates
        matchRows = find(x == dx & y == dy);
        fprintf('  Row %d (vertex_index %d): (%.2f, %.2f) -- same as rows: %s\n', ...
            dRow, vidx(dRow), dx, dy, ...
            mat2str(matchRows'));
    end
end

%% Step 4: Check boundary closure

fprintf('\n--- Boundary Closure Check ---\n');

firstPt = [x(1), y(1)];
lastPt  = [x(end), y(end)];
closureDist = sqrt((lastPt(1)-firstPt(1))^2 + (lastPt(2)-firstPt(2))^2);

fprintf('First point: (%.2f, %.2f) at vertex_index %d\n', firstPt, vidx(1));
fprintf('Last  point: (%.2f, %.2f) at vertex_index %d\n', lastPt, vidx(end));
fprintf('Closure distance: %.6f m\n', closureDist);

if closureDist < 1e-6
    fprintf('Boundary is CLOSED (first == last point).\n');
    isClosed = true;
else
    fprintf('WARNING: Boundary is NOT closed! Gap = %.2f m\n', closureDist);
    isClosed = false;
end

%% Step 5: Check segment lengths (detect discontinuities)

fprintf('\n--- Segment Length Analysis ---\n');

dx = diff(x);
dy = diff(y);
segLengths = sqrt(dx.^2 + dy.^2);

fprintf('Min segment length: %.2f m\n', min(segLengths));
fprintf('Max segment length: %.2f m\n', max(segLengths));
fprintf('Mean segment length: %.2f m\n', mean(segLengths));
fprintf('Median segment length: %.2f m\n', median(segLengths));
fprintf('Std segment length: %.2f m\n', std(segLengths));

% Flag abnormally long segments (potential discontinuities)
threshold = mean(segLengths) + 5 * std(segLengths);
longSegs = find(segLengths > threshold);
fprintf('\nSegments > mean + 5*std (%.2f m): %d\n', threshold, length(longSegs));
if ~isempty(longSegs)
    fprintf('Long segment locations (potential discontinuities):\n');
    for i = 1:min(20, length(longSegs))
        si = longSegs(i);
        fprintf('  Between row %d and %d: %.2f m (vertex_index %d -> %d)\n', ...
            si, si+1, segLengths(si), vidx(si), vidx(si+1));
    end
    if length(longSegs) > 20
        fprintf('  ... and %d more\n', length(longSegs) - 20);
    end
end

%% Step 6: Clean the data for Elmer

fprintf('\n--- Preparing Clean Data for Elmer ---\n');

% Remove the closing duplicate point (Elmer handles closure internally)
if isClosed
    xClean = x(1:end-1);
    yClean = y(1:end-1);
    fprintf('Removed closing duplicate point.\n');
else
    xClean = x;
    yClean = y;
end

% Remove any remaining duplicate points (keep first occurrence)
coordsClean = [xClean, yClean];
[~, keepIdx] = unique(coordsClean, 'rows', 'stable');
removedCount = length(xClean) - length(keepIdx);
xClean = xClean(keepIdx);
yClean = yClean(keepIdx);
fprintf('Removed %d interior duplicate points.\n', removedCount);

% Re-index sequentially starting from 1
newIdx = (1:length(xClean))';
fprintf('Clean boundary: %d points, sequential index [1, %d]\n', ...
    length(xClean), length(xClean));

%% Step 7: Visualization

figure('Name', 'Antarctica Boundary Check', 'Position', [100 100 1400 600]);

% Full boundary plot
subplot(1, 2, 1);
plot(x, y, 'b-', 'LineWidth', 0.5);
hold on;
plot(x(1), y(1), 'go', 'MarkerSize', 10, 'MarkerFaceColor', 'g');
plot(x(end), y(end), 'rs', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
if ~isempty(longSegs)
    for i = 1:length(longSegs)
        si = longSegs(i);
        plot(x(si:si+1), y(si:si+1), 'r-', 'LineWidth', 2);
    end
end
title('Antarctica Boundary (Original)');
xlabel('X (m, EPSG:3031)');
ylabel('Y (m, EPSG:3031)');
legend('Boundary', 'Start point', 'End point', 'Long segments', ...
    'Location', 'best');
axis equal; grid on;

% Segment length histogram
subplot(1, 2, 2);
histogram(segLengths, 100);
hold on;
xline(threshold, 'r--', 'LineWidth', 1.5);
title('Segment Length Distribution');
xlabel('Segment Length (m)');
ylabel('Count');
legend('Segments', sprintf('Threshold (%.0f m)', threshold));
grid on;

%% Step 8: Export clean boundary CSV for Elmer

outputFile = 'Antarctica_Boundary_clean.csv';
cleanTable = table(newIdx, xClean, yClean, ...
    'VariableNames', {'id', 'x', 'y'});
writetable(cleanTable, outputFile);
fprintf('\nClean boundary saved to: %s\n', outputFile);
fprintf('  Points: %d\n', height(cleanTable));
fprintf('  Ready for Elmer mesh generation.\n');

fprintf('\n=== Check Complete ===\n');
