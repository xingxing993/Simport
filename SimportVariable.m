classdef SimportVariable < handle
    properties
        Name
        FileName
        InterpMethod = 'linear' % zoh, linear, message
        Dimension
        SampleRate
        Descriptor
        DataSourceFile
        
        Time
        Data
        
        UserData
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
    end
end