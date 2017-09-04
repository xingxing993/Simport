classdef MDFFile
    %MDFFILE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        FileName
        MDFsummary
        MDFstructure
        counts
        channelList
    end
    
    methods
        %%
        function obj=MDFFile(varargin)
            if nargin<1
                [filename, pathname] = uigetfile( ...
                    {'*.dat','INCA MDF-files (*.dat)';
                    '*.*',  'All Files (*.*)'}, ...
                    'Pick a file');
                if isequal(filename,0) || isequal(pathname,0)
                    return;
                else
                    obj.FileName=fullfile(pathname, filename);
                end
            else
                obj.FileName=varargin{1};
            end
            [obj.MDFsummary, obj.MDFstructure, obj.counts, channelList]=mdfinfo(obj.FileName);
            channelList(:,1)=strtok(channelList(:,1),'\');
            obj.channelList=channelList;
        end
        
       %%
       function data=GetDataByName(obj,signalname)
            allsignames=strtok(obj.channelList(:,1),'\');
           [tf,idx]=ismember(signalname,allsignames);
           if tf
               selectedChannel=obj.channelList(idx,:); %cell
               data=mdfread(obj.MDFstructure,selectedChannel{4},selectedChannel{3});
               data=data{1};
           else
               data=[];
           end
       end
    end
    
end

