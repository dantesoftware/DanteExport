function xt = spaceTime(route,type)

xt = repmat(0,length(route),288);
for x=1:length(route)
    seg = route(x);
    speed = seg.getProperty(type);
    
    if length(speed.values)~=288
        continue;
    end
    
    for t=1:288
        xt(x,t) = speed.values(t);
    end
end


end