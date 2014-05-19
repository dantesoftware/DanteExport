function [n] = DanteNetworkViewer(varargin)

% Shows a network of downloaded Dante data which allows visual inspection
% of element properties (e.g. link IDs), element connections (what is 
% connected to what), detector data (flow, speed), etc.
%
% Note: It is assumed that the file 'DanteExport.jar' is in your java 
% classpath. To to this use javaaddpath('DanteExport.jar').
%
%
% Syntax:
%
%  DanteNetworkViewer
%      Requests for a data folder and data file through dialogs. For the
%      data file one can click 'cancel'. In that case no dynamic data is
%      loaded, but the network is displayed.
%
%  DanteNetworkViewer(dataFolder)
%      Loads a network from the given folder which is displayed without
%      dynamic data.
%
%  DanteNetworkViewer(dataFolder, dataFile)
%      Loads a network from the given folder and loads dynamic data from
%      the given data file.
%
%
% Usage tips of the window:
% 1)   You can zoom (by scrolling) and pan the map with your mouse.
% 2)   The zoom is reset by dubbel clicking on the map.
% 3)   The various categories of elements can be shown or hidden by 
%      right-clicking on the map and selecting the appropriate item.
% 4)   You can view information of an element by clicking on it. The
%      information appears in the upper-left info panel.
% 5)   By clicking on a line in the upper-left panel which is about a
%      connected element, the connected element is shown in the lower-left
%      info panel.
% 6)   By clicking on a line regarding measurement data in the upper-left 
%      info panel, the data is plotted in a seperate window.
% 7)   By dubbel clicking any line in either of the info panels, the line
%      is shown in de Command Window of Matlab. This allows you to
%      copy+paste element names, element data values, etc.
% 8)   Links that are collored red have 0 lanes (i.e. probably unknown).
%
% 23-01-2014    1st version
%
% Created by Wouter Schakel, Delft University of Technology.

% Import java code
import nl.fileradar.dante.export.graph.*;

% Try to create network (we don't want the user to browse to a folder and
% file only to find out that DanteExport.jar is not loaded yet...
try
    n = ENetwork;
catch
    error(['Could not create a new ENetwork. Make sure that ''DanteExport.jar'''...
        ' is in your java classpath by using javaaddpath(''DanteExport.jar'').']);
end

% Check input
if nargin==0
    % Get files using dialogs
    dataFolder = uigetdir(cd, 'Please select a network folder');
    if isnumeric(dataFolder)
        % cancelled
        clear n;
        return
    end
    [file, path, filter] = uigetfile('*.dpnz', 'Please select a data file (cancel for none)', dataFolder);
    if isnumeric(file)
        % cancelled, no dynamic data
        dataFile = [];
    else
        dataFile = [path file];
    end
elseif nargin==1
    % Get data folder
    dataFolder = varargin{1};
    % No dynamic data
    dataFile = [];
elseif nargin==2
    % Get folder and data file from input
    dataFolder = varargin{1};
    dataFile = varargin{2};
else
    error('DanteNetworkViewer requires 0, 1 or 2 inputs')
end

% Load network
n.loadNetwork(dataFolder);

% Load dynamic data
if ~isempty(dataFile)
    n.loadData(dataFile);
end

% Create figure
fig = figure('MenuBar', 'none', 'Toolbar', 'none', 'Name', 'NetworkViewer',...
    'NumberTitle', 'off', 'Color', [1 1 1], 'WindowScrollWheelFcn', @scroll,...
    'ButtonDownFcn', @figClicked, 'WindowButtonUpFcn', @figClickedUp,...
    'WindowButtonMotionFcn', @mouseMoved, 'ResizeFcn', @figResize);
w = .4; % fraction of screen width of left info panels
% axes
ax = axes('Parent', fig, 'Position', [w 0 1-w 1], 'Visible', 'off', 'NextPlot', 'add');
% context menu
hcmenu = uicontextmenu('Parent', fig);
uimenu(hcmenu, 'Callback', @contextMenuItem, 'Checked', 'on', 'UserData', 'l', 'Label', 'Links');
uimenu(hcmenu, 'Callback', @contextMenuItem, 'Checked', 'on', 'UserData', 'n', 'Label', 'Nodes');
uimenu(hcmenu, 'Callback', @contextMenuItem, 'Checked', 'on', 'UserData', 'r', 'Label', 'Ramp lines');
uimenu(hcmenu, 'Callback', @contextMenuItem, 'Checked', 'on', 'UserData', 'o', 'Label', 'Other lines');
uimenu(hcmenu, 'Callback', @contextMenuItem, 'Checked', 'on', 'UserData', 'c', 'Label', 'Carriageway detectors');
uimenu(hcmenu, 'Callback', @contextMenuItem, 'Checked', 'on', 'UserData', 'd', 'Label', 'Lane detectors');
uimenu(hcmenu, 'Callback', @contextMenuItem, 'Checked', 'on', 'UserData', 'p', 'Label', 'Points');
set(fig, 'UIContextMenu', hcmenu);
% listboxes
txt(1) = uicontrol(fig, 'Style', 'listbox', 'Units', 'Normalized',...
    'Position', [0 .5 w .5], 'String', 'Click on network item to obtain info',...
    'BackgroundColor', [1 1 1], 'FontName', 'Courier New', 'FontSize', 8, 'Callback', @txtClick);
txt(2) = uicontrol(fig, 'Style', 'listbox', 'Units', 'Normalized',...
    'Position', [0 0 w .5], 'String', '', 'BackgroundColor', [1 1 1],...
    'FontName', 'Courier New', 'FontSize', 8, 'Callback', @txtClick);

disp('Plotting all elements, this may take a little while.')

% Links
links = [];
for i = 0:n.nElements-1
    el = n.elements.get(i);
    if instanceOf(el, 'nl.fileradar.dante.export.graph.ELink')
        [x y] = getElementGeometry(el);
        lanes = el.getProperty('NWBLink.nLanes').asInt();
        c = [0 0 1];
        ls = '-';
        if lanes==0
            lanes = 1;
            c = [1 0 0];
        end
        p = plot(ax, x, y, 'LineWidth', lanes, 'Color', c, 'LineStyle', ls);
        set(p, 'UserData', composePlotUserData(el, txt), 'ButtonDownFcn', @itemClicked);
        links = [links p];
    end
end

% Lines
ramps = [];
others = [];
for i = 0:n.nElements-1
    el = n.elements.get(i);
    if instanceOf(el, 'nl.fileradar.dante.export.graph.ELine')
        [x y] = getElementGeometry(el);
        c = [0 0 0];
        type = getLineType(el);
        if ~strcmp(type, 'unknown')
            lanes = el.getProperty([type '.nLanes']).asInt();
        else
            lanes = 0;
        end
        if lanes==0
            c = [1 0 0];
        else
            c = [0 1 0];
        end
        ls = ':';
        if lanes==0
            assumedLanes = 1;
        else
            assumedLanes = lanes;
        end
        if sum(c)>0
            p = plot(ax, x, y, 'LineWidth', assumedLanes, 'Color', c, 'LineStyle', ls);
            set(p, 'UserData', composePlotUserData(el, txt), 'ButtonDownFcn', @itemClicked);
        end
        if lanes==0
            others = [others; p];
        else
            ramps = [ramps; p];
        end
    end
end

% Nodes
nodes = [];
for i = 0:n.nElements-1
    el = n.elements.get(i);
    if instanceOf(el, 'nl.fileradar.dante.export.graph.ENode')
        [x y] = getElementGeometry(el);
        p = plot(ax, x, y, 'Marker', 'o', 'Color', [0 0 1]);
        set(p, 'UserData', composePlotUserData(el, txt), 'ButtonDownFcn', @itemClicked);
        nodes = [nodes p];
    end
end

% CarriageWayDetectors
cars = [];
for i = 0:n.nElements-1
    el = n.elements.get(i);
    if instanceOf(el, 'nl.fileradar.dante.export.graph.ECarriageWayDetector')
        [x y] = getElementGeometry(el);
        linked = false;
        for j = 0:el.connections.size()-1
            if instanceOf(el.connections.get(j).to(), 'nl.fileradar.dante.export.graph.ELink')
                linked = true;
            end
        end
        c = [1 0 0];
        if linked
            c = [.5 0 0];
        end
        p = plot(x, y, 'Marker', 's', 'Color', c);
        set(p, 'UserData', composePlotUserData(el, txt), 'ButtonDownFcn', @itemClicked)
        cars = [cars p];
    end
end

% LaneDetectors
lanes = [];
for i = 0:n.nElements-1
    el = n.elements.get(i);
    if instanceOf(el, 'nl.fileradar.dante.export.graph.ELaneDetector')
        [x y] = getElementGeometry(el);
        p = plot(x, y, 'Marker', 's', 'Color', [1 1 0]);
        set(p, 'UserData', composePlotUserData(el, txt), 'ButtonDownFcn', @itemClicked)
        lanes = [lanes p];
    end
end

% Points
points = [];
for i = 0:n.nElements-1
    el = n.elements.get(i);
    if instanceOf(el, 'nl.fileradar.dante.export.graph.EPoint')
        [x y] = getElementGeometry(el);
        p = plot(x, y, 'Marker', 'o', 'Color', [0 .5 0], 'MarkerSize', 2, 'MarkerFaceColor', [0 .5 0]);
        set(p, 'UserData', composePlotUserData(el, txt), 'ButtonDownFcn', @itemClicked)
        points = [points p];
    end
end

% Remember the various handles
dat.l = links;
dat.r = ramps;
dat.o = others; % other ELines
dat.n = nodes;
dat.c = cars;
dat.d = lanes;
dat.p = points;
dat.ax = ax;
set(gcf, 'UserData', dat);

% Initial zoom/panning info for the axes
axDat.factor = 1;
axDat.panning = false;
set(ax, 'UserData', axDat);


%%%%%%%%%%%%%
% CALLBACKS %
%%%%%%%%%%%%%

% Change zoom
function scroll(src, evt)
% determine if over axes
[isOver fX fY axPos] = mouseIsOverAxes(src);
if isOver
    dat = get(src, 'UserData');
    xLim = get(dat.ax, 'XLim');
    yLim = get(dat.ax, 'YLim');
    % get coordinate under mouse
    x0 = xLim(1) + fX*(xLim(2)-xLim(1));
    y0 = yLim(1) + fY*(yLim(2)-yLim(1));
    % get new width and height
    pow = evt.VerticalScrollCount*evt.VerticalScrollAmount;
    if pow<0
        factor = (1/1.05)^-pow;
    else
        factor = 1.05^pow;
    end
    w = (xLim(2)-xLim(1))*factor;
    h = (yLim(2)-yLim(1))*factor;
    xLim = [x0-fX*w x0+(1-fX)*w];
    yLim = [y0-fY*h y0+(1-fY)*h];
    set(dat.ax, 'XLim', xLim, 'YLim', yLim);
    axDat = get(dat.ax, 'UserData');
    axDat.factor = axDat.factor * factor;
    set(dat.ax, 'UserData', axDat);
end

% Starts panning or resets zoom
function figClicked(src, evt)
if strcmp(get(src, 'SelectionType'), 'normal')
    % determine if over axes
    [isOver fX fY axPos] = mouseIsOverAxes(src);
    if isOver
        figDat = get(src, 'UserData');
        xLim = get(figDat.ax, 'XLim');
        yLim = get(figDat.ax, 'YLim');
        axDat = get(figDat.ax, 'UserData');
        axDat.panning = true;
        axDat.mpp = (xLim(2)-xLim(1))/axPos(3);
        axDat.xLimPan = xLim;
        axDat.yLimPan = yLim;
        axDat.pPan = get(0, 'PointerLocation');
        set(figDat.ax, 'UserData', axDat);
    end
elseif strcmp(get(src, 'SelectionType'), 'open')
    % reset zoom
    figDat = get(src, 'UserData');
    axDat = get(figDat.ax, 'UserData');
    set(figDat.ax, 'XLim', axDat.xLim, 'YLim', axDat.yLim);
    % store zoom
    axDat.factor = 1;
    set(figDat.ax, 'UserData', axDat);
end

% Panning
function mouseMoved(src, evt)
figDat = get(src, 'UserData');
axDat = get(figDat.ax, 'UserData');
if axDat.panning
    d = (axDat.pPan-get(0, 'PointerLocation')) * axDat.mpp;
    set(figDat.ax, 'XLim', axDat.xLimPan+d(1), 'YLim', axDat.yLimPan+d(2))
end

% Ends panning
function figClickedUp(src, evt)
figDat = get(src, 'UserData');
axDat = get(figDat.ax, 'UserData');
axDat.panning = false;
set(figDat.ax, 'UserData', axDat);

% Adjust default zoom and apply current zoom in figure resized.
function figResize(src, evt)
% Get user data
figDat = get(src, 'UserData');
axDat = get(figDat.ax, 'UserData');
% Get axes position
units = get(figDat.ax, 'Units');
set(figDat.ax, 'Units', 'pixels');
axPos = get(figDat.ax, 'Position');
set(figDat.ax, 'Units', units); % reset position units
% Get current axes center
x0 = mean(get(figDat.ax, 'XLim'));
y0 = mean(get(figDat.ax, 'YLim'));
% Let matlab do its auto stuff to determine the default zoom
set(figDat.ax, 'DataAspectRatioMode', 'auto', 'XLimMode', 'auto', 'YLimMode', 'auto');
xLim = get(figDat.ax, 'XLim');
yLim = get(figDat.ax, 'YLim');
w = (xLim(2)-xLim(1));
h = (yLim(2)-yLim(1));
% Adjust w/h ratio to match axPos to get an even data aspect ratio
if w/h > axPos(3)/axPos(4)
    % match h
    h = w*axPos(4)/axPos(3);
else
    % match w
    w = h*axPos(3)/axPos(4);
end
axDat.xLim = [mean(xLim)-.5*w mean(xLim)+.5*w];
axDat.yLim = [mean(yLim)-.5*h mean(yLim)+.5*h];
set(figDat.ax, 'UserData', axDat)
% Now apply the current zoom
w = w*axDat.factor;
h = h*axDat.factor;
xLim = [x0-.5*w x0+.5*w];
yLim = [y0-.5*h y0+.5*h];
set(figDat.ax, 'XLim', xLim, 'YLim', yLim);

% Function to show/hide plotted elements through the context menu.
function contextMenuItem(src, evt)
fig = ancestor(src, 'Figure');
dat = get(fig, 'UserData');
field = get(src, 'UserData');
if strcmp(get(src, 'Checked'), 'on')
    stat = 'off';
else
    stat = 'on';
end
set(src, 'Checked', stat)
set(dat.(field), 'Visible', stat);

% Callback when a plotted item was clicked. Displays element info.
function itemClicked(h, evt)
dat = get(h, 'UserData');

assignin('base','selectedElement',dat.element);

udat.elements = displayElementInTextBox(dat.element, dat.txt(1));
udat.txt = dat.txt(2);
% Userdata contains info for the second info panel.
set(dat.txt(1), 'UserData', udat);
set(udat.txt, 'String', '', 'Value', 1);

% Callback when item in first info panel is clicked.
function txtClick(h, evt)
% On double-click, display text in command window (alows copy-paste operations)
val = get(h, 'Value');
if strcmp(get(ancestor(h, 'figure'), 'SelectionType'), 'open')
    str = get(h, 'String');
    disp(strtrim(str{val}));
    return;
end
% Skip in case no item was ever selected
udat = get(h, 'UserData');
if isempty(udat)
    return; 
end

% Plot selected PReliableFloatArray in seperate window
if ~isempty(udat.elements{val}) && instanceOf(udat.elements{val}, 'nl.fileradar.dante.export.property.PReliableFloatArray')
    figure('NumberTitle', 'off', 'MenuBar', 'none', 'Name', char(udat.elements{val}.getName()));
    axes;
    values = udat.elements{val}.values;
    values(udat.elements{val}.reliability) = NaN;
    n = length(values);
    plot((0:n-1)/60, values);
elseif ~isempty(udat.elements{val})
    % Display info about selected element in 2nd info panel
    displayElementInTextBox(udat.elements{val}, udat.txt);
else
    set(udat.txt, 'String', '', 'Value', 1);
end


%%%%%%%%%%%%%%%%%%%%
% HELPER FUNCTIONS %
%%%%%%%%%%%%%%%%%%%%

% Figures out if the mouse is over the axes and returns some additional info
function [isOver fX fY axPos] = mouseIsOverAxes(fig)
p = get(0,'PointerLocation');
figPos = get(fig, 'Position');
p(1:2) = p(1:2)-figPos(1:2); % change origin from screen to window
dat = get(fig, 'UserData');
units = get(dat.ax, 'Units');
set(dat.ax, 'Units', 'pixels');
axPos = get(dat.ax, 'Position');
set(dat.ax, 'Units', units); % reset position units
if p(1)>axPos(1) && p(1)<axPos(1)+axPos(3) && p(2)>axPos(2) && p(2)<axPos(2)+axPos(4)
    isOver = true;
    fX = (p(1)-axPos(1))/axPos(3);
    fY = (p(2)-axPos(2))/axPos(4);
else
    isOver = false;
    fX = [];
    fY = [];
end

% Composes a userdata for a plot handle which contains: handle of info
% panels and the java element that was plotted.
function dat = composePlotUserData(el, txt)
dat.element = el;
dat.txt = txt;

% Displays info about an element in an info panel. Returns a list of
% elements associated with the various lines of info text.
function elements = displayElementInTextBox(element, txt)
elements = {};
% Type
str = strcat('Element Hash: ', {char(element.getHash())});
str{end+1} = ['Element Class: ', char(element.getClass().getName())];
if instanceOf(element, 'nl.fileradar.dante.export.graph.ELink')
    len = linkLength(element);
    str{end+1} = ['Link length = ' num2str(len) 'm'];
end
str{end+1} = '';
% Direct attributes
str{end+1} = 'Direct attributes:';
fs = fields(element);
for i = 1:length(fs)
    % Skip list of connections and properties
    if ~strcmp(fs{i}, 'connections') && ~strcmp(fs{i}, 'properties')
        try
            % Assume an object
            str{end+1} = ['(' fs{i} ') ' char(element.(fs{i}).toString())];
        catch
            % Apperantly a number
            str{end+1} = ['(' fs{i} ') ' num2str(element.(fs{i}))];
        end
    end
end
str{end+1} = '';
% Properties
str{end+1} = 'Properties:';
fullStr = char(element.listProperties());
ind = 0;
while strfind(fullStr, ['(' num2str(ind) ')']);
    strInd1 = strfind(fullStr, ['(' num2str(ind) ')']);
    strInd2 = strfind(fullStr, ['(' num2str(ind+1) ')']);
    if ~isempty(strInd2)
        strInd2 = strInd2-1;
    else
        strInd2 = length(fullStr);
    end
    str{end+1} = fullStr(strInd1:strInd2);
    if instanceOf(element.properties.get(ind), 'nl.fileradar.dante.export.property.PReliableFloatArray')
        elements{length(str)} = element.properties.get(ind);
    end
    ind = ind+1;
end
str{end+1} = '';
% Connections
str{end+1} = 'Connections:';
for i = 0:element.connections.size()-1
    str{end+1} = char(element.connections.get(i).to.toString());
    elements{length(str)} = element.connections.get(i).to;
end
% Select first to prevent selection>lines-of-text
set(txt, 'String', str, 'Value', 1);

% Checks if the element is of given class
function res = instanceOf(element, class)
str = char(element.getClass().toString());
res = false;
if length(str)<length(class)
    return;
end
i = strfind(str, class);
if isempty(i)
    return;
end
res = length(class) == length(str)-i+1;

% Retreives the geometry of an element
function [x y] = getElementGeometry(element)
m = element.geometry.points.size();
x = zeros(m,1);
y = zeros(m,1);
for j = 0:m-1
    coords = element.geometry.points.get(j);
    x(j+1) = coords(1);
    y(j+1) = coords(2);
end

% Gets the type if an ELine
function type = getLineType(line)
dot = [];
i = 0;
while isempty(dot)
    % It must be a something.something name, othersize its for example a 'geomtery'
    if i>=line.properties.size()
        type = 'unknown';
        return
    end
    name = char(line.properties.get(i).getName);
    i = i+1;
    dot = strfind(name, '.');
end
type = name(1:dot-1);

% Calculates the length of a link
function len = linkLength(element)
len = 0;
[x y] = getElementGeometry(element);
for i = 1:length(x)-1
    len = len+sqrt(diff(x(i:i+1))^2 + diff(y(i:i+1))^2);
end