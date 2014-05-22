function xt = spaceTime(route,type)

if strcmpi(type,'detector speed')
    detectors = route.detectors;
    xt = [];
    for d=1:length(detectors)
        det = detectors(d);
        xt = [xt double(det.getProperty('speed').values)];
    end
    xt = xt';
    
elseif strcmpi(type,'detector flow')
    detectors = route.detectors;
    xt = [];
    for d=1:length(detectors)
        det = detectors(d);
        xt = [xt double(det.getProperty('flow').values)];
    end
    
     xt = xt';
    
elseif strcmpi(type,'asm speed')
    segments = route.segments;
    xt = repmat(0,length(segments),288);
    for x=1:length(segments)
        seg = segments(x);
        speed = seg.getProperty('ASM Speed');
        
        if isempty(speed) || length(speed.values)~=288
            continue;
        end
        
        for t=1:288
            xt(x,t) = speed.values(t);
        end
    end
elseif strcmpi(type,'asm flow')
    segments = route.segments;
    xt = repmat(0,length(segments),288);
    for x=1:length(segments)
        seg = segments(x);
        flow = seg.getProperty('ASM Flow');
        
        if isempty(flow) || length(flow.values)~=288
            continue;
        end
        
        for t=1:288
            xt(x,t) = flow.values(t);
        end
    end
end


end