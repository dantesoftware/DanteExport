function plotRoute(route)

% get figure
figHandles = findobj('Type','figure');
for h=1:length(figHandles)
    f = figure(figHandles(h));
    if strcmp(get(f,'name'),'NetworkViewer')
        myFigure = f;
    end
end

if isempty(myFigure)
    return;
end

%activate my figure
myFigure;
hold on;
segments = route.segments;
for s=1:length(segments)
    el = segments(s);
    [x y] = getElementGeometry(el);
    ls = '-';
    plot(gca, x, y, 'LineWidth', 5, 'Color', [0.5 0.8 0.6], 'LineStyle', ls);
end

end

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
end

function dat = composePlotUserData(el, txt)
dat.element = el;
dat.txt = txt;
end