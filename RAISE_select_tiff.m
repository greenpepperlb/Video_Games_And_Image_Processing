function RAISE_select_tiff(csvPath, outputDir)
%RAISE_SELECT_TIFF Browse RAISE metadata, preview TIFFs, and export one image.
%   RAISE_SELECT_TIFF() reads /Users/laurent/Downloads/RAISE_285.csv.
%   RAISE_SELECT_TIFF(csvPath) reads a different RAISE CSV.
%   RAISE_SELECT_TIFF(csvPath, outputDir) writes downloads and exports there.

if nargin < 1 || strlength(string(csvPath)) == 0
    csvPath = "/Users/laurent/Downloads/RAISE_285.csv";
end

thisFolder = fileparts(mfilename("fullpath"));
if nargin < 2 || strlength(string(outputDir)) == 0
    outputDir = fullfile(thisFolder, "RAISE_selected");
end

csvPath = string(csvPath);
outputDir = string(outputDir);
downloadDir = fullfile(outputDir, "downloads");
exportDir = fullfile(outputDir, "exports");
ensureFolder(downloadDir);
ensureFolder(exportDir);

data = readtable(csvPath, "TextType", "string", "VariableNamingRule", "preserve");
requireColumns(data, ["File", "TIFF", "NEF"]);

varNames = string(data.Properties.VariableNames);
displayVars = keepExisting(varNames, ["File", "Keywords", "Device", "Lens", ...
    "Image Size", "ISO Sensitivity", "Aperture", "Shutter Speed", ...
    "Exposure Mode", "Focal Length"]);
searchVars = keepExisting(varNames, ["File", "Keywords", "Device", "Lens", ...
    "Image Size", "ISO Sensitivity", "Aperture", "Shutter Speed", ...
    "Exposure Mode", "Focal Length"]);

visibleIdx = (1:height(data)).';
selectedVisibleRow = 1;
currentImage = [];
currentFileId = "";
currentTiffPath = "";
currentInfo = [];

fig = uifigure("Name", "RAISE TIFF chooser", "Position", [80 80 1280 760]);
fig.CloseRequestFcn = @(src, ~) delete(src);

mainGrid = uigridlayout(fig, [1 2]);
mainGrid.ColumnWidth = {440, "1x"};
mainGrid.RowHeight = {"1x"};
mainGrid.Padding = [10 10 10 10];
mainGrid.ColumnSpacing = 10;

leftPanel = uipanel(mainGrid, "Title", "RAISE records");
leftPanel.Layout.Row = 1;
leftPanel.Layout.Column = 1;

leftGrid = uigridlayout(leftPanel, [8 1]);
leftGrid.RowHeight = {28, 24, "1x", 92, 32, 32, 32, 24};
leftGrid.Padding = [8 8 8 8];
leftGrid.RowSpacing = 8;

searchGrid = uigridlayout(leftGrid, [1 2]);
searchGrid.ColumnWidth = {58, "1x"};
searchGrid.Padding = [0 0 0 0];
uilabel(searchGrid, "Text", "Search");
searchField = uieditfield(searchGrid, "text");
searchField.ValueChangedFcn = @(~, ~) filterRows();

summaryLabel = uilabel(leftGrid, "Text", "");

recordsTable = uitable(leftGrid);
recordsTable.Data = data(visibleIdx, displayVars);
recordsTable.ColumnName = cellstr(displayVars);
recordsTable.RowName = "numbered";
recordsTable.SelectionChangedFcn = @(~, event) selectTableRow(event);

detailsArea = uitextarea(leftGrid, "Editable", "off");

buttonGrid1 = uigridlayout(leftGrid, [1 2]);
buttonGrid1.ColumnWidth = {"1x", "1x"};
buttonGrid1.Padding = [0 0 0 0];
previewButton = uibutton(buttonGrid1, "push", "Text", "Preview / Download TIFF");
previewButton.ButtonPushedFcn = @(~, ~) previewSelected();
nefButton = uibutton(buttonGrid1, "push", "Text", "Download NEF");
nefButton.ButtonPushedFcn = @(~, ~) downloadNefSelected();

buttonGrid2 = uigridlayout(leftGrid, [1 2]);
buttonGrid2.ColumnWidth = {"1x", "1x"};
buttonGrid2.Padding = [0 0 0 0];
save8Button = uibutton(buttonGrid2, "push", "Text", "Save 8-bit TIFF");
save8Button.ButtonPushedFcn = @(~, ~) saveCurrentTiff(8);
save16Button = uibutton(buttonGrid2, "push", "Text", "Save 16-bit TIFF");
save16Button.ButtonPushedFcn = @(~, ~) saveCurrentTiff(16);

buttonGrid3 = uigridlayout(leftGrid, [1 2]);
buttonGrid3.ColumnWidth = {"1x", "1x"};
buttonGrid3.Padding = [0 0 0 0];
openDownloadsButton = uibutton(buttonGrid3, "push", "Text", "Open downloads");
openDownloadsButton.ButtonPushedFcn = @(~, ~) openFolder(downloadDir);
openExportsButton = uibutton(buttonGrid3, "push", "Text", "Open exports");
openExportsButton.ButtonPushedFcn = @(~, ~) openFolder(exportDir);

sourceLabel = uilabel(leftGrid, "Text", "Source TIFF not loaded yet");

rightGrid = uigridlayout(mainGrid, [3 1]);
rightGrid.Layout.Row = 1;
rightGrid.Layout.Column = 2;
rightGrid.RowHeight = {"1x", 28, 28};
rightGrid.Padding = [0 0 0 0];
rightGrid.RowSpacing = 8;

useImageShow = exist("viewer2d", "file") == 2 && exist("imageshow", "file") == 2;
imageObject = [];
previewAxes = [];

if useImageShow
    viewer = viewer2d(rightGrid);
    viewer.Layout.Row = 1;
    viewer.Layout.Column = 1;
    imageObject = imageshow([], Parent=viewer, DisplayRangeMode="data-range");
else
    previewAxes = uiaxes(rightGrid);
    previewAxes.Layout.Row = 1;
    previewAxes.Layout.Column = 1;
    previewAxes.Visible = "off";
end

imageInfoLabel = uilabel(rightGrid, "Text", "Choose a row and click Preview / Download TIFF.");
imageInfoLabel.Layout.Row = 2;
statusLabel = uilabel(rightGrid, "Text", "Ready");
statusLabel.Layout.Row = 3;

refreshTable();
updateDetails();

    function filterRows()
        query = lower(strtrim(string(searchField.Value)));
        if strlength(query) == 0
            visibleIdx = (1:height(data)).';
        else
            rowText = strings(height(data), 1);
            for k = 1:numel(searchVars)
                rowText = rowText + " " + lower(string(data.(char(searchVars(k)))));
            end
            tokens = split(query);
            mask = true(height(data), 1);
            for k = 1:numel(tokens)
                token = strtrim(tokens(k));
                if strlength(token) > 0
                    mask = mask & contains(rowText, token);
                end
            end
            visibleIdx = find(mask);
        end
        selectedVisibleRow = 1;
        currentImage = [];
        currentFileId = "";
        currentTiffPath = "";
        currentInfo = [];
        refreshTable();
        updateDetails();
    end

    function refreshTable()
        recordsTable.Data = data(visibleIdx, displayVars);
        summaryLabel.Text = sprintf("%d matching records from %d rows", ...
            numel(visibleIdx), height(data));
    end

    function selectTableRow(event)
        selectedRow = selectedRowFromTableEvent(event, recordsTable);
        if isempty(selectedRow)
            return
        end
        selectedVisibleRow = selectedRow;
        currentImage = [];
        currentFileId = "";
        currentTiffPath = "";
        currentInfo = [];
        updateDetails();
    end

    function updateDetails()
        if isempty(visibleIdx)
            detailsArea.Value = {"No matching records."};
            sourceLabel.Text = "Source TIFF not loaded yet";
            return
        end

        idx = selectedDataIndex();
        lines = [
            "File: " + valueAt(idx, "File")
            "Keywords: " + valueAt(idx, "Keywords")
            "Device: " + valueAt(idx, "Device")
            "Lens: " + valueAt(idx, "Lens")
            "Image size: " + valueAt(idx, "Image Size")
            "Exposure: " + valueAt(idx, "Aperture") + ", " + ...
                valueAt(idx, "Shutter Speed") + ", " + valueAt(idx, "ISO Sensitivity")
            "TIFF URL: " + tiffUrlFor(idx)
            ];
        detailsArea.Value = cellstr(lines);

        if isempty(currentInfo)
            sourceLabel.Text = "Source TIFF not loaded yet";
        else
            sourceLabel.Text = sourceDescription(currentInfo);
        end
    end

    function idx = selectedDataIndex()
        if isempty(visibleIdx)
            error("RAISE:NoSelection", "No rows match the current search.");
        end
        selectedVisibleRow = max(1, min(selectedVisibleRow, numel(visibleIdx)));
        idx = visibleIdx(selectedVisibleRow);
    end

    function previewSelected()
        try
            idx = selectedDataIndex();
            currentTiffPath = downloadTiff(idx);
            currentInfo = imfinfo(currentTiffPath);
            currentImage = imread(currentTiffPath);
            currentFileId = valueAt(idx, "File");
            displayImage(currentImage);
            sourceLabel.Text = sourceDescription(currentInfo);
            imageInfoLabel.Text = sprintf("%s | %d x %d | %s", currentFileId, ...
                currentInfo(1).Width, currentInfo(1).Height, sourceDescription(currentInfo));
            statusLabel.Text = "Preview loaded from " + currentTiffPath;
        catch err
            uialert(fig, err.message, "Preview failed");
            statusLabel.Text = "Preview failed";
        end
    end

    function localPath = downloadTiff(idx)
        fileId = valueAt(idx, "File");
        localPath = fullfile(downloadDir, safeFileName(fileId) + ".TIF");
        if isfile(localPath)
            statusLabel.Text = "Using cached TIFF: " + localPath;
            return
        end

        url = tiffUrlFor(idx);
        statusLabel.Text = "Downloading TIFF: " + url;
        drawnow;
        progress = uiprogressdlg(fig, "Title", "Downloading TIFF", ...
            "Message", "Downloading " + fileId + ".TIF", "Indeterminate", "on");
        cleanup = onCleanup(@() closeProgress(progress));
        try
            websave(localPath, url);
        catch err
            if isfile(localPath)
                delete(localPath);
            end
            rethrow(err)
        end
    end

    function downloadNefSelected()
        try
            idx = selectedDataIndex();
            fileId = valueAt(idx, "File");
            localPath = fullfile(downloadDir, safeFileName(fileId) + ".NEF");
            if ~isfile(localPath)
                url = nefUrlFor(idx);
                statusLabel.Text = "Downloading NEF: " + url;
                drawnow;
                progress = uiprogressdlg(fig, "Title", "Downloading NEF", ...
                    "Message", "Downloading " + fileId + ".NEF", "Indeterminate", "on");
                cleanup = onCleanup(@() closeProgress(progress));
                try
                    websave(localPath, url);
                catch err
                    if isfile(localPath)
                        delete(localPath);
                    end
                    rethrow(err)
                end
            end
            statusLabel.Text = "Downloaded NEF: " + localPath;
            uialert(fig, "The NEF is the camera RAW source. Use a RAW converter if you need a true high-bit-depth TIFF from the sensor data.", ...
                "NEF downloaded", "Icon", "info");
        catch err
            uialert(fig, err.message, "NEF download failed");
            statusLabel.Text = "NEF download failed";
        end
    end

    function saveCurrentTiff(targetBits)
        try
            if isempty(currentImage)
                previewSelected();
            end
            if isempty(currentImage)
                return
            end

            fileId = safeFileName(currentFileId);
            if targetBits == 8
                out = toUint8Image(currentImage);
                suffix = "_8bit.tif";
            else
                out = toUint16Image(currentImage);
                suffix = "_16bit.tif";
            end

            outPath = fullfile(exportDir, fileId + suffix);
            imwrite(out, outPath, "tif", "Compression", "lzw");
            statusLabel.Text = "Saved " + targetBits + "-bit TIFF: " + outPath;

            if targetBits == 16 && sourceBitsPerSample(currentInfo) <= 8
                uialert(fig, "This source TIFF is 8 bits/channel. The 16-bit export preserves the same visual values scaled into a 16-bit container, but it does not recover extra RAW dynamic range.", ...
                    "16-bit export note", "Icon", "warning");
            end
        catch err
            uialert(fig, err.message, "Export failed");
            statusLabel.Text = "Export failed";
        end
    end

    function displayImage(im)
        if useImageShow
            imageObject.Data = im;
        else
            shown = previewRgb(im);
            image(previewAxes, shown);
            axis(previewAxes, "image");
            previewAxes.Visible = "off";
        end
    end

    function url = tiffUrlFor(idx)
        url = normalizeRaiseUrl(valueAt(idx, "TIFF"), valueAt(idx, "File"), "TIFF", ".TIF");
    end

    function url = nefUrlFor(idx)
        url = normalizeRaiseUrl(valueAt(idx, "NEF"), valueAt(idx, "File"), "NEF", ".NEF");
    end

    function s = valueAt(idx, columnName)
        if ~ismember(columnName, varNames)
            s = "";
            return
        end
        values = data.(char(columnName));
        v = values(idx);
        if iscell(v)
            v = v{1};
        end
        s = strip(string(v));
    end
end

function ensureFolder(folderPath)
if ~isfolder(folderPath)
    mkdir(folderPath);
end
end

function requireColumns(data, names)
varNames = string(data.Properties.VariableNames);
missing = setdiff(names, varNames);
if ~isempty(missing)
    error("RAISE:MissingColumns", "The CSV is missing required columns: %s", ...
        strjoin(missing, ", "));
end
end

function kept = keepExisting(varNames, requested)
kept = requested(ismember(requested, varNames));
end

function url = normalizeRaiseUrl(sourceUrl, fileId, folderName, extension)
sourceUrl = strip(string(sourceUrl));
fileId = strip(string(fileId));

if strlength(sourceUrl) > 0
    [~, sourceName, sourceExt] = fileparts(char(sourceUrl));
    if strlength(string(sourceName)) > 0
        fileId = string(sourceName);
    end
    if strlength(string(sourceExt)) > 0
        extension = string(sourceExt);
    end
end

url = "https://loki.disi.unitn.it/RAISE/" + folderName + "/" + fileId + extension;
end

function name = safeFileName(fileId)
name = regexprep(strip(string(fileId)), "[^A-Za-z0-9_-]", "_");
end

function desc = sourceDescription(info)
bits = sourceBitsPerSample(info);
if bits > 0
    desc = sprintf("source TIFF: %g bits/channel, %s", bits, classFromInfo(info));
else
    desc = "source TIFF loaded";
end
end

function bits = sourceBitsPerSample(info)
bits = 0;
if isempty(info)
    return
end
info = info(1);
if isfield(info, "BitsPerSample") && ~isempty(info.BitsPerSample)
    bits = max(double(info.BitsPerSample));
elseif isfield(info, "BitDepth") && ~isempty(info.BitDepth)
    bits = double(info.BitDepth);
    if isfield(info, "ColorType") && strcmpi(string(info.ColorType), "truecolor")
        bits = bits / 3;
    end
end
end

function cls = classFromInfo(info)
if isfield(info(1), "ColorType")
    cls = string(info(1).ColorType);
else
    cls = "image";
end
end

function closeProgress(progress)
if isvalid(progress)
    close(progress);
end
end

function row = selectedRowFromTableEvent(event, tableHandle)
selection = [];
if nargin >= 1 && ~isempty(event)
    selection = selectionProperty(event, "Indices");
    if isempty(selection)
        selection = selectionProperty(event, "Selection");
    end
end

if isempty(selection) && nargin >= 2 && isvalid(tableHandle)
    selection = tableHandle.Selection;
end

row = firstSelectionRow(selection);
end

function value = selectionProperty(obj, propertyName)
value = [];
if isstruct(obj)
    if isfield(obj, propertyName)
        value = obj.(propertyName);
    end
elseif isobject(obj) && isprop(obj, propertyName)
    value = obj.(propertyName);
end
end

function row = firstSelectionRow(selection)
row = [];
if isempty(selection)
    return
end

if isnumeric(selection)
    row = selection(1, 1);
    return
end

rows = selectionProperty(selection, "Rows");
if isempty(rows)
    rows = selectionProperty(selection, "Row");
end
if isempty(rows)
    rows = selectionProperty(selection, "Indices");
end
if isempty(rows) && iscell(selection)
    rows = selection{1};
end

if ~isempty(rows)
    row = rows(1);
end
end

function openFolder(folderPath)
folderPath = char(folderPath);
if ispc
    winopen(folderPath);
elseif ismac
    system(sprintf('open "%s"', strrep(folderPath, '"', '\"')));
else
    system(sprintf('xdg-open "%s"', strrep(folderPath, '"', '\"')));
end
end

function out = toUint8Image(im)
if isa(im, "uint8")
    out = im;
elseif isa(im, "uint16")
    out = uint8(round(double(im) / 257));
elseif isinteger(im)
    out = uint8(round(double(im) * 255 / double(intmax(class(im)))));
else
    out = uint8(round(255 * clamp01(double(im))));
end
end

function out = toUint16Image(im)
if isa(im, "uint16")
    out = im;
elseif isa(im, "uint8")
    out = uint16(im) * uint16(257);
elseif isinteger(im)
    out = uint16(round(double(im) * 65535 / double(intmax(class(im)))));
else
    out = uint16(round(65535 * clamp01(double(im))));
end
end

function out = clamp01(x)
out = min(max(x, 0), 1);
end

function shown = previewRgb(im)
shown = toUint8Image(im);
if ismatrix(shown)
    shown = repmat(shown, 1, 1, 3);
end
end
