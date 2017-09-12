function d = h2dXX(h)
% 1. all hex value are in upper case
% 2. message data all have 2-digits hex value

% h = upper(h);

if h(1)>57
    h(1)=h(1)-55; % 'A':65->65
else
    h(1)=h(1)-48;
end
if h(2)>57
    h(2)=h(2)-55; % 'A':65->65
else
    h(2)=h(2)-48;
end
d = h(1)*16+h(2);
end