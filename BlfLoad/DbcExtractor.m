function [modulename, DBC_O] = DbcExtractor(varargin)
    % =====================================================================
    % input file check
    % =====================================================================
    fileready = 0;
    DBC_O = struct;
      
    if ~isempty(varargin)
        if ~isempty(varargin{1,1})
            filetoread = varargin{1,1};
            [~,~,ext] = fileparts(filetoread);

            if strcmpi(ext, '.dbc') && exist(filetoread,'file') == 2
                fileready = 1;
                filetoread = which(filetoread);
            end
        end
    end
    
    if ~fileready
        [filename, pathname] = uigetfile( ...
            {'*.dbc', 'Vector CANdb database (*.dbc)'; ...
             '*.*', 'CAN dbc file in txt format (*.*)'}, 'Pick a dbc file');
        if filename==0
            modulename = '';
            return;
        end
        filetoread = fullfile(pathname, filename); 
    end

    dbc = fileread(filetoread);
    
    % =====================================================================
    % global variables
    % =====================================================================
    global bitmatrix CRLF
%     bitmatrix = [7 :-1: 0;...
%                 15 :-1: 8;...
%                 23 :-1: 16;...
%                 31 :-1: 24;...
%                 39 :-1: 32;...
%                 47 :-1: 40;...
%                 55 :-1: 48;...
%                 63 :-1: 56];
%     bitmatrix = reshape(bitmatrix',1,64);
    bitmatrix = reshape(fliplr(reshape(0:511,8,64)')',512,1)';
    CRLF = [char(13) char(10)];
    
    % =====================================================================
    % dbc process
    % =====================================================================
    BOblks = regexp(dbc, ['BO_ \d{1,} [a-zA-Z_].*?' CRLF CRLF], 'match')';
    BOblks_ = cellfun(@BOstruct,BOblks,'UniformOutput',false);
    DBC_O = vertcat(BOblks_{:});
    
    % =====================================================================
    % write module file
    % =====================================================================
    % [pathname, filename] = fileparts(filetoread);
    % filename = strcat('module_', filename, '.m');
    % filetowrite = fullfile(pathname,filename);
    [~, modulename, ~] = fileparts(filetoread);
    
    clear global bitmatrix CRLF
end

% #########################################################################
% =========================================================================
% sub-function definitions
% =========================================================================
% #########################################################################

% =========================================================================
% BOstruct
% =========================================================================
function BOblk_O =BOstruct(BOblk)
    global CRLF
    BOblk_O = cell(1,3);
    
    BOinfo = strsplit(BOblk, CRLF);
    if length(BOinfo) > 1
        SGblks = BOinfo(2:end-1);
        SGblks_ = cellfun(@SGstruct,SGblks,'UniformOutput',false);
        BOblk_O{1,3} = vertcat(SGblks_{:});
    end
    BOinfo = BOinfo{1};
    BOinfo = strsplit(BOinfo);
    if strcmp(BOinfo{3}(end),':')
        BOblk_O{1,1} = BOinfo{3}(1:end-1);
    else
        BOblk_O{1,1} = BOinfo{3};
    end
    BOblk_O{1,2} = str2double(BOinfo{2});
end

% =========================================================================
% SGstruct
% =========================================================================
function SGblk_O = SGstruct(SGblk)
    SGinfo = strsplit(SGblk);
    SGblk_O= cell(1,3);
    SGblk_O{1} = SGinfo{3};
    SGblk_O{2} = SGalgo(SGinfo{5}, SGinfo{6});
    SGblk_O{3} = SGinfo{8}(2:end-1);
end

% =========================================================================
% SGalgo
% =========================================================================
function SGalgostr = SGalgo(SGbit, SG2phy)
    global bitmatrix
    SGalgostr = '';
    
    % bit operation
    % ---------------------------------------------------------------------
    sigbitinfo = regexp(SGbit,'(\d+)\|(\d+)@(\d)','tokens');
    sigstart = str2double(sigbitinfo{1}{1});
    siglength = str2double(sigbitinfo{1}{2});
    Endianness = str2double(sigbitinfo{1}{3});
    
    if Endianness==0 
    % motorola
    % ---------------------------------------------------------------------
        bitend_idx = find(bitmatrix==sigstart,1); % 34
        bitstart_idx = bitend_idx + siglength - 1; % 49
    else
    % intel
    % ---------------------------------------------------------------------
        bitstart_idx = find(bitmatrix==sigstart,1);
        bitend_idx = find(bitmatrix==(sigstart + + siglength - 1),1);      
    end
    
    bitend_bytepos = ceil(bitend_idx/8); % 5
    bitstart_bytepos   = ceil(bitstart_idx/8);% 7
    
    % for shift
    % ---------------------------------------------------------------------
    bit_temp = mod(bitend_idx,8);% 7
    if bit_temp
        bitend_bitpos = 8 - bit_temp + 1;
    else
        bitend_bitpos = 1;
    end
    
    bit_temp = mod(bitstart_idx,8);% 8
    if bit_temp
        bitstart_bitpos = 8 - bit_temp + 1;
    else
        bitstart_bitpos = 1;
    end
    
    loopnum = abs(bitstart_bytepos - bitend_bytepos) + 1;
    sigmat = zeros(loopnum, 5);
    
    % which byte
    % start bit pos this line
    % end bit pos this line
    % bit cnt this line
    % bit cnt sum previous line
    % ---------------------------------------------------------------------
    if loopnum == 1
        sigmat(loopnum, 1) = bitstart_bytepos;
        sigmat(loopnum, 2) = bitstart_bitpos;
        sigmat(loopnum, 3) = bitend_bitpos;
        sigmat(loopnum, 4) = sigmat(loopnum, 3) - sigmat(loopnum, 2) + 1;
        sigmat(loopnum, 5) = 0;
    else
        for i=1:loopnum
            if i==1
                sigmat(i, 1) = bitstart_bytepos;
                sigmat(i, 2) = bitstart_bitpos;
                sigmat(i, 3) = 8;
                sigmat(i, 4) = sigmat(i, 3) - sigmat(i, 2) + 1;
                sigmat(i, 5) = 0;
            elseif i<loopnum
                if Endianness == 0
                    sigmat(i, 1) = sigmat(i-1, 1) - 1; % motorola
                else
                    sigmat(i, 1) = sigmat(i-1, 1) + 1; % intel
                end
                sigmat(i, 2) = 1;
                sigmat(i, 3) = 8;
                sigmat(i, 4) = sigmat(i, 3) - sigmat(i, 2) + 1;
                sigmat(i, 5) = sigmat(i-1, 5) + sigmat(i-1, 4);
            else % i==loopnum
                sigmat(i, 1) = bitend_bytepos;
                sigmat(i, 2) = 1;
                sigmat(i, 3) = bitend_bitpos;
                sigmat(i, 4) = sigmat(i, 3) - sigmat(i, 2) + 1;
                sigmat(i, 5) = sigmat(i-1, 5) + sigmat(i-1, 4);
            end
        end
        
    end
    
    % str
    bb = 'bb';
    for j=1:loopnum
       if j>1
          SGalgostr = [' + ' SGalgostr];  
       end
       str = [bb '(' num2str(sigmat(j, 1)) ',:)'];
       
       if sigmat(j, 4)==1
           str = ['bitget(' str ',' num2str(sigmat(j, 2)) ')'];
       else
           if sigmat(j, 2)~=1
               str = ['bitshift(' str ',-' num2str(sigmat(j, 2)-1) ')'];
           end
           if sigmat(j, 4)~=8
               str = ['bitand(' str ',' num2str(2^sigmat(j, 4)-1) ')'];
           end
       end       
       
       if sigmat(j, 5)~=0
           str = ['2^' num2str(sigmat(j, 5)) ' * ' str];
       end
       SGalgostr = [str SGalgostr];
    end
    
    SGalgostr = ['(' SGalgostr ')'];
    
    % gain offset operation
    % --------------------------------------------
    sig2phy = regexp(SG2phy,'\((.*),(.*)\)','tokens');
    siggain = str2double(sig2phy{1}{1});
    sigoffs = str2double(sig2phy{1}{2});
    
    if siggain~=1
        SGalgostr = [sprintf('%0.6e', siggain) '*' SGalgostr];
    end
    
    if sigoffs~=0
    	SGalgostr = [SGalgostr ' + ' sprintf('%0.2f',sigoffs) ';'];
    else
        SGalgostr = [SGalgostr ';'];
    end
end
