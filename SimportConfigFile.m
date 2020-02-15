function varargout = SimportConfigFile(varargin)
% SIMPORTCONFIGFILE MATLAB code for SimportConfigFile.fig
%      SIMPORTCONFIGFILE, by itself, creates a new SIMPORTCONFIGFILE or raises the existing
%      singleton*.
%
%      H = SIMPORTCONFIGFILE returns the handle to a new SIMPORTCONFIGFILE or the handle to
%      the existing singleton*.
%
%      SIMPORTCONFIGFILE('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in SIMPORTCONFIGFILE.M with the given input arguments.
%
%      SIMPORTCONFIGFILE('Property','Value',...) creates a new SIMPORTCONFIGFILE or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before SimportConfigFile_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to SimportConfigFile_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help SimportConfigFile

% Last Modified by GUIDE v2.5 13-Sep-2017 22:56:52

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @SimportConfigFile_OpeningFcn, ...
                   'gui_OutputFcn',  @SimportConfigFile_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before SimportConfigFile is made visible.
function SimportConfigFile_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to SimportConfigFile (see VARARGIN)

% Choose default command line output for SimportConfigFile
handles.output = hObject;
flobjcells = varargin{1};
handles.FileObjects = varargin{1};
if numel(flobjcells)<1
    errordlg('No file has been imported');
    return;
end

figresize(handles,numel(flobjcells));
tbldata = cell(numel(flobjcells), 4);
for i=1:size(tbldata,1)
    [~, name, ext] = fileparts(flobjcells{i}.FileName);
    tbldata{i,1} = [name, ext];
    tbldata{i,2} = flobjcells{i}.ZeroStart;
    tbldata{i,3} = flobjcells{i}.TimeOffset;
    tbldata{i,4} = flobjcells{i}.TimeGain;
end
set(handles.filetable,'Data',tbldata);

% Update handles structure
guidata(hObject, handles);
uiwait(handles.SimportConfigFile);


% UIWAIT makes SimportConfigFile wait for user response (see UIRESUME)
% uiwait(handles.SimportConfigFile);


% --- Outputs from this function are returned to the command line.
function varargout = SimportConfigFile_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
% varargout{1} = handles.output;


% --- Executes on button press in btn_ok.
function btn_ok_Callback(hObject, eventdata, handles)
% hObject    handle to btn_ok (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
tbldata = get(handles.filetable,'Data');
for i=1:size(tbldata,1)
    handles.FileObjects{i}.ZeroStart = tbldata{i,2};
    handles.FileObjects{i}.TimeOffset = tbldata{i,3};
    handles.FileObjects{i}.TimeGain = tbldata{i,4};
end
uiresume(handles.SimportConfigFile);
close(handles.SimportConfigFile);

% --- Executes on button press in btn_cancel.
function btn_cancel_Callback(hObject, eventdata, handles)
% hObject    handle to btn_cancel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
uiresume(handles.SimportConfigFile);
close(handles.SimportConfigFile);

% --- Executes on button press in btn_apply.
function btn_apply_Callback(hObject, eventdata, handles)
% hObject    handle to btn_apply (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
tbldata = get(handles.filetable,'Data');
for i=1:size(tbldata,1)
    handles.FileObjects{i}.ZeroStart = tbldata{i,2};
    handles.FileObjects{i}.TimeOffset = tbldata{i,3};
    handles.FileObjects{i}.TimeGain = tbldata{i,4};
end


function figresize(handles,rowcnt)
%Adjust size
figpos=get(handles.SimportConfigFile,'Position');
tblpos=get(handles.filetable,'Position');
pnlpos=get(handles.btngrppanel,'Position');
dht=max(round(18.4*rowcnt+30-tblpos(4)), 0);
scrnsz=get(0,'ScreenSize');
if dht>(scrnsz(4)-figpos(4))
    dht=scrnsz(4)-figpos(4)-60;
    dwth=16; %width for slider bar
else
    dwth=0;
end
% dht=min([dht,scrnsz(4)-figpos(4)]);
figpos(4)=figpos(4)+dht;
figpos(2)=figpos(2)-dht;
figpos(3)=figpos(3)+dwth;
tblpos(4)=tblpos(4)+dht;
tblpos(3)=tblpos(3)+dwth;
set(handles.SimportConfigFile,'Position',figpos);
set(handles.filetable,'Position',tblpos);
% pnlpos(2)=pnlpos(2)+dht;
% set(handles.btngrppanel,'Position',pnlpos);


% --- Executes when user attempts to close SimportConfigFile.
function SimportConfigFile_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to SimportConfigFile (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: delete(hObject) closes the figure
delete(hObject);


% --- Executes during object deletion, before destroying properties.
function SimportConfigFile_DeleteFcn(hObject, eventdata, handles)
% hObject    handle to SimportConfigFile (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
