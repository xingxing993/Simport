function varargout = BlfLoad(varargin) 
    % =====================================================================
    % input file check
    % =====================================================================
    fileready = 0;
    
    if ~isempty(varargin)
        filetoread = varargin{1,1};
        [~,~,ext] = fileparts(filetoread);
        
        if strcmpi(ext, '.blf') && exist(filetoread,'file') == 2
            fileready = 1;
            % 'which' command cannot return fullpath if the input path is 
            % not full & is not on the Matlab's search path
            % 
            % temporarily add this non-full path onto search path solve the
            % problem
            tmp = which(filetoread);
            if isempty(tmp)
                pathtoadd = fileparts(filetoread);
                addpath(pathtoadd);
                tmp = which(filetoread);
                if ~isempty(tmp)
                    filetoread = tmp;
                    pathname = fileparts(filetoread);
                else
                    fileready = 0;
                end
                rmpath(pathtoadd);
            else
                filetoread = tmp;
                pathname = fileparts(filetoread);
            end
        end
    end
    
    if ~fileready
        [filename, pathname] = uigetfile( ...
            {'*.blf', 'Canoe/Canalyzer Files (*.blf)';}, 'Pick a blf file');
        if filename==0
            if nargout > 0
                varargout{1,1} = [];
            end
            return;
        end
        filetoread = fullfile(pathname, filename); 
    end
    
    switchFlag = 0;
    if nargin==2
        switchFlag = varargin{1,2};
    end
    
    if pathname(end) == '\'
        pathname = pathname(1:end-1);
    end
    
    %----------------------------------------------------------------------
    tic
    % =====================================================================
    % call DbcExtractor
    % =====================================================================
    matlabPath = path;
    pathFlag = isempty(strfind(matlabPath, pathname));
    addpath(pathname)
    clearnup = onCleanup(@()rmMatlabPath(pathname, pathFlag));
    miscResult = MiscWriter(pathname);
    if ~miscResult
        if nargout > 0
            varargout{1,1} = [];
        end
        fprintf(2, '\n\t%s\n\n', 'Please select corresponding dbc files!')
        return;
    end

    % =====================================================================
    % call mex function BlfExtractor
    % =====================================================================
    [b,msg,chan,tm]=BlfExtractor(filetoread, 789456.0, switchFlag);

    % =====================================================================
    % call can_module_ext
    % =====================================================================
    can = can_module_ext(b,msg,chan,tm);
    if nargout==0
        assignin('base', 'can', can)
    else
        varargout{1,1} = can;
    end
    % ---------------------------------------------------------------------
    toc
end

% =====================================================================
% call cleanup
% =====================================================================
function rmMatlabPath(pathIn, pathFlag)
    if pathFlag
        rmpath(pathIn);
        fclose('all');
    end
end