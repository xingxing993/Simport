function result = MiscWriter(pathname)
    % =====================================================================
    % check towrite m-files
    % =====================================================================
    files_struct = dir(pathname);
    files_name = {files_struct.name}';
    [~,filenames,exts] = cellfun(@fileparts,files_name,'UniformOutput',0);
    ext_dbc_bool = strcmpi(exts,'.dbc');
    ext_dbc_idx = find(ext_dbc_bool);
    
    modulenamepart = filenames(ext_dbc_bool);
    modulenames = strcat('module_', modulenamepart, '.m');
    
    module_exist_idx = ismember(modulenames,files_name);
    dbc_towrite_idx = ext_dbc_idx(~module_exist_idx);
    dbc_towrite_file = files_name(dbc_towrite_idx);
    identify_towrite_file = filenames(dbc_towrite_idx);
    
    % =====================================================================
    % call sub-functions
    % =====================================================================
    if isempty(dbc_towrite_file)
        modulenamep_tmp = 'SNC6SI';
        DBC_O = {};
        while ~isempty(modulenamep_tmp)
            [modulenamep_tmp, DBC_O_tmp] = DbcExtractor;
            if isempty(modulenamep_tmp)
                if isempty(modulenamepart)
                    result = false;
                    return;
                end
            else
                modulenamepart = [modulenamepart; modulenamep_tmp];
                DBC_O = [DBC_O; {DBC_O_tmp}];
            end
        end
        for i=1:numel(modulenamepart)
            % write module_(xxx).m
            % -------------------------------------------------------------
            WriteModule(DBC_O{i}, modulenamepart{i}, pathname);
            % write identify_(xxx).m
            % -------------------------------------------------------------
            WriteIdentify(DBC_O{i}, modulenamepart{i}, pathname);
        end
    else
        for i=1:numel(dbc_towrite_file)
            % write module_(xxx).m
            % -------------------------------------------------------------
            [~, DBC_O] = DbcExtractor(dbc_towrite_file{i});
            WriteModule(DBC_O, modulenamepart{i}, pathname);
            % write identify_(xxx).m
            % -------------------------------------------------------------
            WriteIdentify(DBC_O, identify_towrite_file{i}, pathname);
        end 
    end
    
    % write can_module_ext.m
    % ---------------------------------------------------------------------  
    WriteModuleExt(modulenamepart, pathname);
    result = true;
end

% #########################################################################
% =========================================================================
% sub-function definitions
% =========================================================================
% #########################################################################

% =========================================================================
% Write can_module_ext.m
% =========================================================================
function WriteModuleExt(module, pathname)
    functionname = 'can_module_ext';
    filetowrite = fullfile(pathname, functionname);
    fid = fopen([filetowrite '.m'], 'w');
    
    str = ['function can = ' functionname '(b,msg,chan,tm)'];
    fprintf(fid, '%s\n\n', str);
    
    str = 'uniquemsgid = msgidproc(msg,chan);';
    fprintf(fid, '\t%s\n\n', str);
    
    loopnum = size(module,1);
    for i=1:loopnum
        str = ['if exist(''module_' module{i} ''',''file'')'];
        fprintf(fid, '\t%s\n', str);
        
        str = ['if exist(''identify_' module{i} '_can_chan'',''file'')'];
        fprintf(fid, '\t\t%s\n', str);
        
        str = ['CHAN_NUMBER = identify_' module{i} '_can_chan(uniquemsgid);'];
        fprintf(fid, '\t\t\t%s\n', str);
        
        str = ['fprintf(''module_' module{i} ' is on CAN %d\n'',CHAN_NUMBER);'];
        fprintf(fid, '\t\t\t%s\n', str);
        
        str = 'else';
        fprintf(fid, '\t\t%s\n', str);
        
        str = 'CHAN_NUMBER = 1;';
        fprintf(fid, '\t\t\t%s\n', str);
        
        str = 'end';
        fprintf(fid, '\t%s\n', str);
        
        str = ['can_tmp = module_' module{i} '(b,msg,chan,tm,CHAN_NUMBER);'];
        fprintf(fid, '\t\t%s\n\n', str);
        
        str = 'if isstruct(can_tmp)';
        fprintf(fid, '\t\t%s\n', str);
        
        str = 'fields = fieldnames(can_tmp);';
        fprintf(fid, '\t\t\t%s\n', str);
        
        str = 'for k=1:length(fields)';
        fprintf(fid, '\t\t\t%s\n', str);
        
        str = 'can.(fields{k}) = can_tmp.(fields{k});';
        fprintf(fid, '\t\t\t\t%s\n', str);
        
        str = 'end';
        fprintf(fid, '\t\t\t%s\n', str);
        
        str = 'end';
        fprintf(fid, '\t\t%s\n', str);
        
        str = 'end';
        fprintf(fid, '\t%s\n\n\n', str);
        
    end
    
    str = 'end';
    fprintf(fid, '%s\n\n\n', str);
    
    str = {'function uniquemsgid = msgidproc(msg,chan)', ...
    '    canchannels = unique(chan);', ...
    '    max_channel = max(canchannels);', ...
	'    uniquemsgid = cell(1,max_channel);', ...
    '    for i=1:max_channel', ...
    '        if any(i==canchannels)', ...
    '            uniquemsgid{i} = unique(msg(chan==i));', ...
    '        else', ...
    '            uniquemsgid{i} = [];', ...
    '        end', ...
    '    end', ...
    'end'};

    fprintf(fid, '%s\n', str{:});
    
    fclose(fid);    
    
%     pcode([filetowrite '.m'],'-inplace');
%     delete([filetowrite '.m']);
end

% =========================================================================
% WriteIdentify
% =========================================================================
function WriteIdentify(DBC_I, dbcfilename, pathname)
    functionname = ['identify_' dbcfilename '_can_chan'];
    filetowrite = fullfile(pathname, functionname);
    fid = fopen([filetowrite '.m'], 'w');
    
    % header
    % ---------------------------------------------------------------------
    str = ['function CHAN_NUMBER = ' functionname '(uniquemsgid)'];
    fprintf(fid, '%s\n\n\n', str);
    
    str = 'dbcid = [ ...';
    fprintf(fid, '%s\n', str);
    str = DBC_I(:,2);
    fprintf(fid, '\t\t%u,...\n',str{:});
    str = '0];';
    fprintf(fid, '\t\t%s\n',str);
    
    fprintf(fid, '\n');
    
    % loop
    % ---------------------------------------------------------------------
    str = {'    max_channel = numel(uniquemsgid);', ...
    '    chan_counts = zeros(1, max_channel);', ...
    '    for i=1:max_channel', ...
    '        if isempty(uniquemsgid{1,i})', ...
    '            continue;', ...
    '        else', ...
    '            chan_counts(i) = numel(intersect(uniquemsgid{1,i}, dbcid));', ...
    '        end', ...
    '    end', ...
    '    [~, CHAN_NUMBER] = max(chan_counts);'};
    fprintf(fid, '%s\n', str{:});

    fclose(fid);
    
%     pcode([filetowrite '.m'],'-inplace');
%     delete([filetowrite '.m']);
end


% =========================================================================
% WriteModule
% =========================================================================
function WriteModule(DBC_I, filetowrite, pathname)
    functionname = ['module_' filetowrite];
    filetowrite = fullfile(pathname, functionname);
    fid = fopen([filetowrite '.m'], 'w');
    
    str = ['function can = ' functionname '(b,msg,chan,tm,CHANNUM)'];
    fprintf(fid, '%s\n\n\n', str);
    str = 'can=[];';
    fprintf(fid, '%s\n\n', str);
    str = 'ix = (chan == CHANNUM);';
    fprintf(fid, '%s\n', str);
    str = 'if isempty(ix)';
    fprintf(fid, '%s\n', str);
    str = 'return;';
    fprintf(fid, '\t%s\n', str);
    str = 'end';
    fprintf(fid, '%s\n', str);
    str = 'b  = b(:,ix);';
    fprintf(fid, '%s\n', str);
    str = 'tm  = tm(:,ix);';
    fprintf(fid, '%s\n', str);
    str = 'msg  = msg(:,ix);';
    fprintf(fid, '%s\n\n\n', str);
    
    loopnum = size(DBC_I, 1);
    
    for i=1:loopnum
    % msg struct frame
    % ---------------------------------------------------------------------
        str = ['% ' repmat('=',1, 73)];
        fprintf(fid, '%s\n', str);
        
        msg = ['MSG_' dec2hex(DBC_I{i,2})];
        str = [msg ' = ' num2str(DBC_I{i,2}) ';'];
        fprintf(fid, '%s\n\n', str);
        
        str = ['ix=(msg == ' msg ');'];
        fprintf(fid, '%s\n', str);
        
        str = 'if ~isempty(ix)';
        fprintf(fid, '%s\n', str);
        
        str = ['can.' DBC_I{i,1} ...
            ' = struct(''ID_hex'', '''', ''ID_dec'', [], ''nsamples'', 0, ''ctime'', []);'];
        fprintf(fid, '\t%s\n\n', str);
        
        str = 'bb  = b(:,ix);';
        fprintf(fid, '\t%s\n\n', str);
        
        str = ['can.' DBC_I{i,1} '.ID_hex = ''' dec2hex(DBC_I{i,2}) ''';'];
        fprintf(fid, '\t%s\n', str);
        
        str = ['can.' DBC_I{i,1} '.ID_dec = ' num2str(DBC_I{i,2}) ';'];
        fprintf(fid, '\t%s\n', str);
        
        str = ['can.' DBC_I{i,1} '.nsample = length(ix);'];
        fprintf(fid, '\t%s\n', str);
        
        str = ['can.' DBC_I{i,1} '.ctime = tm(ix);'];
        fprintf(fid, '\t%s\n\n', str);
        
    
    % signals
    % ---------------------------------------------------------------------
        for j=1:size(DBC_I{i,3},1)
            str = ['can.' DBC_I{i,1} '.units.' DBC_I{i,3}{j,1} ' = ''' DBC_I{i,3}{j,3} ''';'];
            fprintf(fid, '\t%s\n', str);
            
            str = ['can.' DBC_I{i,1} '.' DBC_I{i,3}{j,1} ' = ' DBC_I{i,3}{j,2}];
            fprintf(fid, '\t%s\n', str);
        end
        
        str = 'end';
        fprintf(fid, '%s\n\n\n', str);
        
    end
    
    fclose(fid);
    
%     pcode([filetowrite '.m'],'-inplace');
%     delete([filetowrite '.m']);
    
end
