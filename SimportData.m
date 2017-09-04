classdef SimportData < timeseries
    %SIMPORTDATA Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        PortNumber
        SourceInfo
    end
    
    methods
        function obj = SimportData(varargin)
           obj = obj@timeseries(varargin{:}); 
        end
    end
    
end

