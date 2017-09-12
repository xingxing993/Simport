function d = h2dMsgID(h)
% faster version of HEX2DEC to speed up mass data transformation

h = upper(h);
n = numel(h);
p = 16.^(n-1:-1:0);


h(h <= 64) = h(h <= 64) - 48; %0-9
h(h > 64) = h(h > 64) - 55; %A-F

d = sum(h.*p);