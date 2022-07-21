classdef SimportFileMDF < SimportFile
    
    properties
        % MDFVarTable
        MDFVarTable
        % Column 1 - Variable names (processed)
        % Column 2 - Channel group number
        % Column 3 - Sub channel ID number in channel group (for mdfread use)
        %           or cell string of raw variable names (for mdf object)
        % Column 4 - Inferred interpolation flag using ChannelDataType,
        %           only "IntegerUnsignedLittleEndian (0)" is assummed as
        %           don't need interpolation
        % asam.mdf.ChannelDataType([0:14]')
        %     0 - IntegerUnsignedLittleEndian
        %     1 - IntegerUnsignedBigEndian   
        %     2 - IntegerSignedLittleEndian  
        %     3 - IntegerSignedBigEndian     
        %     4 - RealLittleEndian           
        %     5 - RealBigEndian              
        %     6 - StringASCII                
        %     7 - StringUTF8                 
        %     8 - StringUTF16LittleEndian    
        %     9 - StringUTF16BigEndian       
        %     10 - ByteArray                  
        %     11 - MIMESample                 
        %     12 - MIMEStream                 
        %     13 - CANOpenDate                
        %     14 - CANOpenTime       
        % Column 5 - Variable names (raw)

        
        %-------------
        MDFstructure %only for use "mdfinfo" and "mdfread" functions by Stuart McGarrity
        
        %-------------
        MDFFileObj % only for use MATLAB built-in "mdf" to process file
    end
    
    properties (Constant)
        PRIORITIZE_BUILTIN_FUNC = true;
    end
    
    methods
        function obj = SimportFileMDF(varargin)
            obj = obj@SimportFile(varargin{:});
            if verLessThan('matlab', '9.1') || ~obj.PRIORITIZE_BUILTIN_FUNC %before R2016b, mdf not available
                % Use "mdfinfo" and "mdfread" functions by Stuart McGarrity to process the MDF
                % file, MDF4.0 is not supported
                %  [mdfsummary, mdfstructure, mdfcounts, mdfchannelList] = mdfinfo(filename);
                [~,obj.MDFstructure, ~, channel_table]=mdfinfo(obj.FileName);
                obj.MDFVarTable = cell(size(channel_table, 1), 5);
                obj.MDFVarTable(:,[1,2,3,end]) = channel_table(:,[1,4,3,1]);
                obj.MDFVarTable(:,4) = num2cell(cell2mat(channel_table(:,8))>0); %refer to the inferred interpolation comment above
            else
                % Use MATLAB built-in "mdf" to process file, better format
                % support, but only available after R2016b
                obj.MDFFileObj = mdf(obj.FileName);
                ch_struarr = vertcat(obj.MDFFileObj.ChannelGroup.Channel); %channel array struct
                obj.MDFVarTable = cell(numel(ch_struarr), 5);
                obj.MDFVarTable(:,[1,3,end]) = repmat({ch_struarr.Name}',1,3);
                % Fill in channel group number
                chcnt_arr = arrayfun(@(cg) numel(cg.Channel), obj.MDFFileObj.ChannelGroup);
                tmpidxarr = [0,cumsum(chcnt_arr)];
                for i=1:numel(tmpidxarr)-1
                    obj.MDFVarTable(tmpidxarr(i)+1:tmpidxarr(i+1), 2) = {i};
                end
                obj.MDFVarTable(:,4) = num2cell([ch_struarr.DataType]'>0); %refer to the inferred interpolation comment above
            end
            
            raw_varlist = obj.MDFVarTable(:,end); %raw name like VAR\DEV:ChNum
            var_list = strtok(raw_varlist,'\'); %remove suffix to keep only variable name part
            nidx_ex_time_and_suffix = find((cellfun(@isempty, regexp(var_list, '^time$|^\$')))); % Exclude 'time' and INCA internal '$XXX' variables
            var_list_ex_time_and_suffix = var_list(nidx_ex_time_and_suffix);
            [c, ia] = unique(var_list_ex_time_and_suffix);
            if numel(c)~=numel(var_list_ex_time_and_suffix) % Duplicates exists in variable list
                nidx_dup = nidx_ex_time_and_suffix(setdiff(1:numel(var_list_ex_time_and_suffix), ia));
                var_list(nidx_dup) = obj.MDFVarTable(nidx_dup,end); % keep duplicate variables raw channel name string
                fprintf('## The following variable have duplicates in different channels,\nmake sure to use the full name as below if you want to use specific variable:\n');
                dupvars = obj.MDFVarTable(nidx_dup,end);
                fprintf('## %s\n', dupvars{:});
            end
            obj.MDFVarTable(:,1) = var_list;
            % routine processing
            obj.UpdateVarObjects;
            obj.VarList = {obj.VarObjects.Name}';
        end
    end
    
    methods
        %% GetData
        function varobjs = LoadData(obj, varnames, reloadflg, ~)
            if nargin<3
                reloadflg = false;
            end
            varobjs=[];
            varnames = cellstr(varnames);
            [coexistvars, ia] = intersect(obj.MDFVarTable(:,1), varnames);
            if isempty(coexistvars)
                return;
            end
            ch_local_tbl = obj.MDFVarTable(ia,:); % only involved channels
            cglist = cell2mat(ch_local_tbl(:,2)); %involved channel groups
            cg_unq=unique(cglist); % find the involved channel groups
            for i=1:numel(cg_unq) % traversal all involved channel groups
                subidx = (cglist==cg_unq(i));
                if verLessThan('matlab', '9.1') || ~obj.PRIORITIZE_BUILTIN_FUNC
                    subchnum = cell2mat(ch_local_tbl(subidx,3));
                    tmpdatas=mdfread(obj.MDFstructure,cg_unq(i),[1;subchnum]);% time channel at #1
                else
                    tmptimetbl = obj.MDFFileObj.read(cg_unq(i), ch_local_tbl(subidx,3));
                    tmptmpdata = table2array(tmptimetbl);
                    tmpdatas = cell(1,size(tmptmpdata,2)+1);
                    tmpdatas{1} = seconds(tmptimetbl.Time);
                    for nc = 1:size(tmptmpdata,2)
                        tmpdatas{nc+1}=tmptmpdata(:,nc);
                    end
                end
                if numel(tmpdatas)==1 %if empty
                    continue;
                end
                % assign varobj.Time and varobj.Data for each variable involved
                subvars = ch_local_tbl(subidx, 1);
                for k=1:numel(subvars)
                    varobj = obj.GetVar(subvars{k});
                    if numel(varobj)>1
                        varobj = varobj(1);
                    end
                    if ~isempty(varobj.Time) && ~reloadflg % if already loaded, do nothing
                    else
                        varobj.Time = (tmpdatas{1}-tmpdatas{1}(1)*obj.ZeroStart)*obj.TimeGain + obj.TimeOffset;
                        varobj.Data = tmpdatas{k+1};
                    end
                    varobjs = [varobjs; varobj];
                end
            end
        end
        
        function varobjs = GetVar(obj, varnames)
            varnames = cellstr(varnames);
            varobjs=[];
            for i=1:numel(varnames)
                varname=varnames{i};
                varobj = obj.VarObjects(strcmp(obj.VarList, varname));
                varobjs = [varobjs;varobj];
            end
        end
        
        %% UpdateVarObjects
        function UpdateVarObjects(obj, varargin)
            tmpidx = strncmp(obj.MDFVarTable(:,1),'$',1) | strcmp(obj.MDFVarTable(:,1),'time'); % find those start with '$' or 'time'
            validchannels = obj.MDFVarTable(~tmpidx,:);
            varobjs = [];
            interpmethod = {'zoh','linear'};
            for i=1:size(validchannels, 1)
                varobjs = [varobjs; ...
                    SimportVariable(...
                    validchannels{i,1},... %name
                    obj.FileName,...
                    interpmethod{validchannels{i,4}+1},... % interpolation method
                    1,... % dimension
                    validchannels{i,5},... %sample rate
                    'MDF')];
            end
            obj.VarObjects = varobjs;
        end
    end

end
