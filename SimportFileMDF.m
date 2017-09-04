classdef SimportFileMDF < SimportFile
    
    properties
        MDFsummary
        MDFstructure
        counts
        channelList
    end
    
    methods
        function obj = SimportFileMDF(varargin)
            obj = obj@SimportFile(varargin{:});
            [obj.MDFsummary, obj.MDFstructure, obj.counts, channelList]=mdfinfo(obj.FileName);
            channelList(:,1)=strtok(channelList(:,1),'\');
            obj.channelList=channelList;
            obj.VarObjects = obj.GetVarObjects;
            obj.VarList = {obj.VarObjects.Name}';
        end
    end
    
    methods
        %% GetData
        function LoadData(obj, varnames)
            varnames = cellstr(varnames);
            [coexistvars, ia] = intersect(obj.channelList(:,1), varnames);
            if isempty(coexistvars)
                return;
            end
            chinfo = obj.channelList(ia,:);
            dblist = cell2mat(chinfo(:,4));
            
            dbs=unique(cell2mat(chinfo(:,4))); % find the involved data blocks
            for i=1:numel(dbs) % traversal all involved data blocks
                subidx = (dblist==dbs(i));
                subchnum = cell2mat(chinfo(subidx,3));
                tmpdatas=mdfread(obj.MDFstructure,dbs(i),[1;subchnum]);%with time channel
                if numel(tmpdatas)==1 %if empty
                    continue;
                end
                subvars = chinfo(subidx, 1);
                for k=1:numel(subvars)
                    varobj = obj.GetVar(subvars{k});
                    varobj.Time = (tmpdatas{1}+obj.TimeOffset)*obj.TimeGain;
                    varobj.Data = tmpdatas{k+1};
                end
            end
        end
        
        function varobj = GetVar(obj, varname)
            varobj = obj.VarObjects(strcmp(obj.VarList, varname));
        end
        
        %% GetVarList
        function varlist = GetVarObjects(obj, varargin)
            tmpidx = strncmp(obj.channelList(:,1),'$',1) | strcmp(obj.channelList(:,1),'time'); % find those start with '$' or 'time'
            validchannels = obj.channelList(~tmpidx,:);
            varlist = [];
            for i=1:size(validchannels, 1)
                varlist = [varlist; ...
                    SimportVariable(...
                    validchannels{i,1},... %name
                    obj.FileName,...
                    validchannels{i,8}>0,... % interpolation
                    1,... % dimension
                    validchannels{i,5},... %sample rate
                    'MDF')];
            end
        end
    end

end