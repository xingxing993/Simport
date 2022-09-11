function flobj = simport_filedispatcher(filename, varargin)
[~,~,EXT]=fileparts(filename);
% return SimportFile object
switch lower(EXT)
    case {'.mdf', '.dat', '.mf4'}
        flobj = SimportFileMDF(filename);
    case '.vsb'
        flobj = SimportFileVSB(filename);
    case '.csv'
        flobj = SimportFileCSV(filename);
    case '.blf'
        flobj = SimportFileBLF(filename);
    case '.asc'
        flobj = SimportFileASC(filename);
    case '.log'
        flobj = SimportFileBMLOG(filename);
    case '.dbc'
        flobj = SimportFileDBC(filename);
%     case '.ascii'
%     case {'.xls', '.xlsx', '.xlsm'}
    
    otherwise
        flobj = [];
end
        
