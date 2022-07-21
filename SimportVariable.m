classdef SimportVariable < handle
    properties
        Name
        FileName
        InterpMethod = 'linear' % zoh, linear, message
        Dimension
        SampleRate
        Descriptor
        
        
        DataSourceFile
        Channel % for data files that have same signal in differrent Channels, like CAN file or some MDF file(suffix removed)
        
        Time
        Data
        
        UserData %dbc signal info for DBC file
    end
    
    properties (Dependent = true)
        TimeRange % [start, end]
    end
    methods
        function obj = SimportVariable(varargin)
            [obj.Name, ...
             obj.FileName, ...
             obj.InterpMethod, ...
             obj.Dimension, ...
             obj.SampleRate, ...
             obj.Descriptor] = deal(varargin{:});
        end
        
        function CalcSampleRate(obj)
            for i=1:numel(obj)
                if ~isempty(obj(i).Time) && isempty(obj(i).SampleRate)
                    tsteps = diff(obj(i).Time);
                    st = mean(tsteps);
                    if st>0&&(std(tsteps)/st<0.2)
                        obj(i).SampleRate = round(st*10000)/10000;
                    else
                        obj(i).SampleRate = -1;
                    end
                end
            end
        end
        
        function  trng = get.TimeRange(obj)
            if isempty(obj.Time)
                trng = [];
            else
                trng = [obj.Time(1), obj.Time(end)];
            end
        end
        
        function plot(obj)
            figure;
            plot(obj.Time, obj.Data);
            title(obj.Name);
        end
        
        function Resample(obj, newtimearr, varargin)
            obj.Data = interp1(obj.Time, obj.Data, newtimearr, varargin{:});
            obj.Time = newtimearr;
        end
        
        function [d, t] = GetValueAtTime(obj, tspec, mode)
            if nargin<3
                mode = 'points'; %versus 'range'
            end
            if isempty(tspec) || isempty(obj.Time)
                t = []; d = [];
                return;
            end
            tspec(tspec<obj.Time(1)) = obj.Time(1);
            tspec(tspec>obj.Time(end)) = obj.Time(end);
            if strcmp(mode, 'range') %tspec = [tstart, tend]
                i1 = find(obj.Time>=tspec(1), 1);
                i2 = find(obj.Time>tspec(2), 1)-1;
                t = obj.Time(i1:i2);
                d = obj.Data(i1:i2);
            elseif numel(tspec)==1
                i1 = find(obj.Time>=tspec, 1);
                t = obj.Time(i1);
                d = obj.Data(i1);
            else
                t = zeros(1,numel(tspec));
                d = zeros(1,numel(tspec));
                for i=1:numel(tspec)
                    k = find(obj.Time>=tspec(i), 1);
                    t(i) = obj.Time(k);
                    d(i) = obj.Data(k);
                end
            end
        end
    end
end