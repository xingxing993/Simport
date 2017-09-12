function actvflg = interpmessage(time, data, newtime)
%INTERPMESSAGE Interpolation of message occurance shot based on time
% the 2nd data is actually no use
it = 1; % old time
nt = numel(time);
actvflg = false(size(newtime)); 
for i=2:numel(newtime)
    lb = newtime(i-1);
    rb = newtime(i);
    % if current point lower than lower bound, first move to cross
    while time(it)<lb % move it left
        if it<nt
            it = it+1;
        else
            actvflg(i-1) = true;
            return; % already reach end of time, no need to go further
        end
    end
    if time(it)>rb
        continue;
    else
        actvflg(i)=true;
    end
end
end

