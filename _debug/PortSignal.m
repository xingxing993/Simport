classdef PortSignal < handle

    
    properties
        PortNum
        Candidates
        DataType
        % read MDF info
        Electee
        BlockIndex
        ChannelIndex
        ChannelInfo
        SampleTime
        bMatch
        MDF_FileName
        MDF_FilePath
        % read data
        RawTime
        RawData
        RawTimeMax
        RawTimeMin
        Time
        TimeMax
        TimeMin
        Data
        
    end

    methods
        %%
        function obj=PortSignal(varargin)
            % Required inputs: Candidate list, DataType
            if nargin==1&&isstr(varargin{1})&&~isempty(strfind(varargin{1},'.xls'))
                %read excel
            else
                if iscellstr(varargin{1})
                    obj.Candidates=varargin{1};
                else
                    obj.Candidates=varargin(1);
                end
                if nargin<2
                    obj.DataType='double';
                else
                    obj.DataType=varargin{2};
                end
                obj.Time=[];
                obj.Data=[];
                if numel(obj.Candidates)>0
                    obj.Electee=obj.Candidates{1};
                else
                    obj.Electee='';
                end
                if nargin>2
                    obj.PortNum=varargin{3};
                end
            end
        end
        %%
        function MatchMDFChannel(objarr,mdf)
            %For object array, update info
            channelList=mdf.channelList;
            allsignames=strtok(channelList(:,1),'\');
            for i=1:numel(objarr)
                [matched,ia,ib]=intersect(objarr(i).Candidates,allsignames);
                if isempty(ia)
                    objarr(i).bMatch=boolean(0);
                    chnl={'','',[],[],[],[],[],[],[],''};
                else
                    objarr(i).bMatch=boolean(1);
                    [tmp,idx]=min(ia);
                    chnl=channelList(ib(idx),:);
                    objarr(i).Electee=chnl{1};
                    objarr(i).BlockIndex=chnl{4};
                    objarr(i).ChannelIndex=chnl{3};
                    objarr(i).SampleTime=chnl{5};
                    objarr(i).ChannelInfo=chnl;
                end
                %reset signal
                objarr(i).Data=[];
                objarr(i).RawData=[];
                objarr(i).Time=[];
                objarr(i).RawTime=[];
                objarr(i).TimeMax=[];
                objarr(i).TimeMin=[];
                objarr(i).RawTimeMax=[];
                objarr(i).RawTimeMin=[];
            end
            [path,name,ext]=fileparts(mdf.FileName);
            [objarr.MDF_FilePath]=deal(path);
            [objarr.MDF_FileName]=deal([name,ext]);
        end
        
        %%
        function bemptyblk=GetMultipleSignalData(objarr,mdf)
            %For object array
            [path,name,ext]=fileparts(mdf.FileName);
            if ~isequal(objarr(1).MDF_FileName,[name,ext])
                objarr.MatchMDFChannel(mdf);
            end
            
            matchobjs=objarr([objarr.bMatch]);
            channels=[];
            for theobj=matchobjs
                channels=[channels;theobj.ChannelInfo];
            end
            if isempty(channels)
                bemptyblk=boolean(1);
                return;
            end
            bemptyblk=boolean(0);
            dblist=cell2mat(channels(:,4));
            dbs=unique(dblist); %DataBlocks involved
            signames=[];
            for i=1:numel(dbs) % traversal all involved data blocks
                idx=dblist==dbs(i);
                thisblockobjs=matchobjs(idx); %
                currentChannels=channels(idx,:);
                [currentdata,currentnames]=mdfread(mdf.MDFstructure,dbs(i),[1;cell2mat(currentChannels(:,3))]);%with time channel
                if numel(currentdata)==1 %if empty
                    continue;
                end
                [thisblockobjs.Data]=deal(currentdata{2:end});
                [thisblockobjs.RawData]=deal(currentdata{2:end});
                [thisblockobjs.Time]=deal(currentdata{1});
                [thisblockobjs.RawTime]=deal(currentdata{1});
            end
            for i=1:numel(matchobjs)
                theobj = matchobjs(i);
                theobj.TimeMax=max(theobj.Time);
                theobj.TimeMin=min(theobj.Time);
                theobj.RawTimeMax=theobj.TimeMax;
                theobj.RawTimeMin=theobj.TimeMin;
            end
        end
        %% UniformizeByTime, for object array only
        function UniformizeByTime(objarr,varargin)
            if nargin<2
                scnt = cellfun(@(e) numel(e), {objarr.RawTime});
                [~, idx] = max(scnt);
                t_arr=objarr(idx).RawTime;
                [objarr.TimeMax]=deal(max(t_arr));
                [objarr.TimeMin]=deal(min(t_arr));
            elseif numel(varargin{1})==1 %given sample time, and tmin, tmax (optional)
                if nargin<3
                    tmin=max([objarr.RawTimeMin]);
                    tmax=min([objarr.RawTimeMax]);
                else
                    [tmin,tmax]=varargin{2:3};
                end
                t_arr=tmin:varargin{1}:tmax;
                [objarr.TimeMax]=deal(tmax);
                [objarr.TimeMin]=deal(tmin);
                [objarr.SampleTime]=deal(varargin{1});
            else % given time array
                t_arr=varargin{1};
                [objarr.TimeMax]=deal(max(t_arr));
                [objarr.TimeMin]=deal(min(t_arr));
            end
            for i=1:numel(objarr)
                obj = objarr(i);
                if isempty([obj.RawTime])||isempty([obj.RawData])
                    continue;
                end
                switch obj.DataType
                    case {'boolean','enum','uint8'}
                        obj.Data=interp1(obj.RawTime,obj.RawData,t_arr,'nearest','extrap');
                    case {'double','single'}
                        obj.Data=interp1(obj.RawTime,obj.RawData,t_arr,'linear','extrap');
                    otherwise
                        obj.Data=interp1(obj.RawTime,obj.RawData,t_arr,'linear','extrap');
                end
            end
            [objarr.Time]=deal(t_arr);
        end
        
        
        %% Deal with time vacancy windows in the data
        function RemoveTimeVacancy(objarr,varargin)
            tol = 0.4; % 80%
            if nargin>1
                vac_value = varargin{1};
            else
                vac_value = NaN;
            end
            for i=1:numel(objarr)
                obj = objarr(i);
                time = obj.RawTime;
                if numel(time)<2
                    return;
                end
                delta_time = diff(time);
                dt = delta_time; k = 1;
                while ~isempty(dt)
                    i_samedt = dt>dt(1)*(1-tol) & dt<dt(1)*(1+tol);
                    dtinfo(k).dt_value = mean(dt(i_samedt));
                    dtinfo(k).count = sum(i_samedt);
                    k = k+1;
                    dt = dt(~i_samedt);
                end
                [~, imax] = max([dtinfo.count]);
                dt_rng = dtinfo(imax).dt_value * [1-tol, 1+tol];
                vacant_pos = find(~(delta_time>=dt_rng(1) & delta_time<=dt_rng(2)));
                for n = 1:numel(vacant_pos)
                    vac_idx = (obj.Time>=time(max(vacant_pos(n), 1))) & (obj.Time<=time(vacant_pos(n)+1));
                    obj.Data(vac_idx) = vac_value;
                end
            end
        end
        
        
        %% Configure model, for object array only
        function ConfigToModel(objarr,model,ts)
            if nargin<3
                ts=min([objarr.SampleTime]);
            end
            if nargin<2
                model=bdroot(gcs);
            end
            %check all ports matched
            inports=find_system(model,'FindAll','on','SearchDepth',1,'BlockType','Inport');
            if numel(unique([objarr.PortNum]))<numel(objarr)
                errordlg('Duplicate port number specified');return;
            elseif ~isempty(setdiff(1:numel(inports),[objarr.PortNum]))
                errordlg('Port %u is not assigned\n',setdiff(1:numel(inports),[objarr.PortNum]));
                return;
            end
            %config
            cfg=getActiveConfigSet(model);
            cfg.Components(1).SolverType='Fixed-step';
            cfg.Components(1).Solver='FixedStepDiscrete';
            tmin=max([objarr.RawTimeMin]);
            tmax=min([objarr.RawTimeMax]);
            cfg.Components(1).StartTime=num2str(tmin);
            cfg.Components(1).StopTime=num2str(tmax);
            cfg.Components(1).FixedStep=num2str(ts);
            %prepare data
            extinputdata.time=objarr([objarr.PortNum]==1).Time; %use the first time array
            for i=1:numel(inports)
                extinputdata.signals(i).values =objarr([objarr.PortNum]==i).Data;
                extinputdata.signals(i).dimensions = 1;            
            end
            assignin('base','extinputdata',extinputdata);
            cfg.Components(2).ExternalInput='extinputdata';
            cfg.Components(2).LoadExternalInput='on';
            cfg.Components(2).MaxDataPoints=num2str(numel(extinputdata.time)+1);
        end
        
        function MatchPortNum(objarr,model)
            %Try to associate object to inports of model by name
            if nargin<2
                model=bdroot(gcs);
            end
            inports=find_system(model,'FindAll','on','SearchDepth',1,'BlockType','Inport');
            ptcnt=numel(inports);
            for i=1:numel(inports)
                portname=get_param(inports(i),'Name');
                for obj=objarr
                    if ismember(portname,obj.Candidates)
                        obj.PortNum=i;
                        break;
                    end
                end
            end
        end
        
        function sigobj = GetSignal(objarr, signame)
            sigobj = objarr(strcmp({objarr.Electee}', signame));
        end
    end
    
end

