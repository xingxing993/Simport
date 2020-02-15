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
            obj.UpdateVarObjects;
            obj.VarList = {obj.VarObjects.Name}';
        end
    end
    
    methods
        %% GetData
        function LoadData(obj, varnames, reloadflg)
            if nargin<3
                reloadflg = false;
            end
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
                    if ~isempty(varobj.Time) && ~reloadflg % if already loaded, return
                        continue;
                    end
                    varobj.Time = (tmpdatas{1}-tmpdatas{1}(1)*obj.ZeroStart)*obj.TimeGain + obj.TimeOffset;
                    varobj.Data = tmpdatas{k+1};
                end
            end
        end
        
        function varobj = GetVar(obj, varname)
            varobj = obj.VarObjects(strcmp(obj.VarList, varname));
        end
        
        %% UpdateVarObjects
        function UpdateVarObjects(obj, varargin)
            tmpidx = strncmp(obj.channelList(:,1),'$',1) | strcmp(obj.channelList(:,1),'time'); % find those start with '$' or 'time'
            validchannels = obj.channelList(~tmpidx,:);
            varobjs = [];
            interpmethod = {'zoh','linear'};
            for i=1:size(validchannels, 1)
                varobjs = [varobjs; ...
                    SimportVariable(...
                    validchannels{i,1},... %name
                    obj.FileName,...
                    interpmethod{(validchannels{i,8}>0)+1},... % interpolation method
                    1,... % dimension
                    validchannels{i,5},... %sample rate
                    'MDF')];
            end
            obj.VarObjects = varobjs;
        end
    end

end