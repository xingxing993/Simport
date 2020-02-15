function varargout = Simport(varargin)
% SIMPORT M-file for Simport.fig
%      SIMPORT, by itself, creates a new SIMPORT or raises the existing
%      singleton*.
%
%      H = SIMPORT returns the handle to a new SIMPORT or the handle to
%      the existing singleton*.
%
%      SIMPORT('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in SIMPORT.M with the given input arguments.
%
%      SIMPORT('Property','Value',...) creates a new SIMPORT or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before Simport_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to Simport_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help Simport

% Last Modified by GUIDE v2.5 13-Sep-2017 23:30:46

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @Simport_OpeningFcn, ...
                   'gui_OutputFcn',  @Simport_OutputFcn, ...
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


% --- Executes just before Simport is made visible.
function Simport_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to Simport (see VARARGIN)

% Choose default command line output for Simport
handles.output = hObject;

handles.CurrentModel=bdroot(gcs);
if isempty(handles.CurrentModel)
    errordlg('No available model opened.');
else
    set(handles.dispinfo,'String',...
        sprintf('Model:  %s',get_param(bdroot(gcs),'Name')));
    refresh_model(handles, 'init');
end

% initialize other infos
handles.HiliteBlocks = [];
handles.VarTable = cell(0,3); % {name, fileidx, varobj}
handles.DataFiles = {};
% Update handles structure
guidata(hObject, handles);


function refresh_model(handles, mode)
if nargin<2
    mode = 'normal';
end
if isempty(handles.CurrentModel)
    rowcnt = 0;
else
    inports=find_system(bdroot(handles.CurrentModel),'FindAll','on','SearchDepth',1,'BlockType','Inport');
    rowcnt=numel(inports);
end
if rowcnt==0
    errordlg('The model contains no inport or outport block');
else
    % update Table display
    if strcmp(mode, 'init')
        tbldata={};
        for i=1:numel(inports)
            tbldata=[tbldata;{'##',get_param(inports(i),'Port'),'',false}];
        end
    else
        tbldata=get(handles.listtable,'Data');
        if rowcnt>size(tbldata,1)
            tbldata=[tbldata;repmat(tbldata(1,:),rowcnt-size(tbldata,1),1)];
        else
            tbldata=tbldata(1:rowcnt,:);
        end
        for i=1:numel(inports)
            tbldata(i,1:2)={'##',get_param(inports(i),'Port')};
        end
    end
    figresize(handles,rowcnt);
    set(handles.listtable,'Data',tbldata);
    set(handles.dispinfo,'String',...
        sprintf('Model:  %s',get_param(handles.CurrentModel,'Name')));
end




% UIWAIT makes Simport wait for user response (see UIRESUME)
% uiwait(handles.Simport);
function figresize(handles,rowcnt)
%Adjust size
figpos=get(handles.Simport,'Position');
tblpos=get(handles.listtable,'Position');
tblextent=get(handles.listtable,'Extent');
pnlpos=get(handles.uipanel_top,'Position');
% dht=tblextent(4)+20-tblpos(4);%table extent + title row
dht=round(18.4*rowcnt+30-tblpos(4));
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
pnlpos(2)=pnlpos(2)+dht;
tblpos(4)=tblpos(4)+dht;
tblpos(3)=tblpos(3)+dwth;
set(handles.Simport,'Position',figpos);
set(handles.listtable,'Position',tblpos);
set(handles.uipanel_top,'Position',pnlpos);

% --- Outputs from this function are returned to the command line.
function varargout = Simport_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = [];


% --- Executes when selected cell(s) is changed in listtable.
function listtable_CellSelectionCallback(hObject, eventdata, handles)
% hObject    handle to listtable (see GCBO)
% eventdata  structure with the following fields (see UITABLE)
%	Indices: row and column indices of the cell(s) currently selecteds
% handles    structure with handles and user data (see GUIDATA)
% disp('aaa');



% --------------------------------------------------------------------
function addfile_ClickedCallback(hObject, eventdata, handles)
% hObject    handle to addfile (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
importfile(handles, 'add'); % import and update


function importfile(handles, mode)
if nargin<2
    mode = 'add';
end
if ~strcmp(mode, 'add')
    handles.DataFiles={};
    handles.VarTable={};
end
if isfield(handles,'DefaultDir')
    defaultdir=handles.DefaultDir;
else
    defaultdir=pwd;
end
[filename, pathname] = uigetfile( ...
    {'*.mdf;*.dat','MDF Logging File(*.mdf;*.dat)'; ...
    '*.blf;*asc','Vector CAN Binary Log File(*.blf) or ASC log(*.asc)'; ...
    '*.vsb;*csv','Interpidcs Vehicle Spy Binary(*.vsb) or CSV log(*.csv)'; ...
    '*.log','BusMaster CAN Log File(*.log)';
    '*.dbc','Vector CANdb database(*.dbc)';}, ...
    'Select data file(s) to import', ...
    'MultiSelect', 'on');
if ~iscell(filename)&&~ischar(filename)
    return;
else
    handles.DefaultDir=pathname;
end
hwaitbar=waitbar(0,'Processing files...');%Display wait bar
set(get(get(hwaitbar,'children'),'title'),'Interpreter','none');%Avoid an annoying warning message
filename=cellstr(strcat(pathname,filename));

for i=1:numel(filename)
    [~,NAME,EXT]=fileparts(filename{i});
    waitbar(i/numel(filename),hwaitbar,sprintf('Processing %s',[NAME EXT]));
    flobj = simport_filedispatcher(filename{i});
    % update and store file information
    handles.DataFiles = [handles.DataFiles; {flobj}];
    tmpvartable = flobj.VarList;
    [tmpvartable{:,2}] = deal(numel(handles.DataFiles));
    tmpvartable(:,3) = arrayfun(@(a)a, flobj.VarObjects, 'UniformOutput', false);
    handles.VarTable = [handles.VarTable; tmpvartable];
end
close(hwaitbar);
update_dropdownlist(handles); % update table popmenu dropdown
guidata(handles.Simport, handles);


function update_dropdownlist(handles)
%Set selection list
colformat=get(handles.listtable,'ColumnFormat');
varlist = handles.VarTable(:,1);
if numel(unique(varlist))<numel(varlist)
    dispvarlist = cellfun(@(name, idx)sprintf('%s@%u', name, idx), handles.VarTable(:,1), handles.VarTable(:,2), 'UniformOutput', false);
else
    dispvarlist = varlist;
end
colformat{3}=sort(dispvarlist)';
set(handles.listtable,'ColumnFormat',colformat);
%


% --- Executes when entered data in editable cell(s) in listtable.
function listtable_CellEditCallback(hObject, eventdata, handles)
% hObject    handle to listtable (see GCBO)
% eventdata  structure with the following fields (see UITABLE)
%	Indices: row and column indices of the cell(s) edited
%	PreviousData: previous data for the cell(s) edited
%	EditData: string(s) entered by the user
%	NewData: EditData or its converted form set on the Data property. Empty if Data was not changed
%	Error: error string when failed to convert EditData to appropriate value for Data
% handles    structure with handles and user data (see GUIDATA)
if eventdata.Indices(2)==3
    tbldata=get(handles.listtable,'data');
    varobj = getvarobject(eventdata.EditData, handles.VarTable);
    if isempty(varobj)
        return;
    end
    infostr = getdescriptor(varobj);
    [tbldata{eventdata.Indices(1),[1,4]}]= deal(infostr, strcmp(varobj.InterpMethod, 'linear'));
    set(handles.listtable,'data',tbldata);
end

function infostr = getdescriptor(varobj)
if varobj.Dimension>1 %if necessary suffix additional dimension info [n]
    infostr = sprintf('%s[%u]', varobj.Descriptor, varobj.Dimension);
else
    infostr = varobj.Descriptor;
end


function [varobj, fileindex] = getvarobject(varname, vartable)
if isempty(vartable)
    varobj = [];
    fileindex = [];
else
    regout = regexp(varname, '(\w+)@(\d+)$', 'once','tokens');
    if ~isempty(regout) % if duplicate variable name, match both name and file index
        varidx = strcmp(regout{1}, vartable(:,1))&...
            strcmp(regout{2}, cellfun(@int2str, vartable(:,2), 'UniformOutput', false));
    else
        varidx = strcmp(varname, vartable(:,1));
    end
    if ~any(varidx)
        error('Simport: Failed to find variable "%s" in imported data file', varname);
    else
        varobj = vartable{varidx, end};
        fileindex = vartable{varidx, 2};
    end
end


% --------------------------------------------------------------------
function select_model_ClickedCallback(hObject, eventdata, handles)
% hObject    handle to select_model (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
mdls = find_system('type', 'block_diagram', 'BlockDiagramType', 'model');
if isempty(mdls)
    errordlg('No available model opened');
else
    [s,v] = listdlg('PromptString','Select target model:',...
        'SelectionMode','single',...
        'ListString',mdls);
    if v
        handles.CurrentModel = mdls{s};
        refresh_model(handles, 'normal');
        guidata(hObject, handles);
    end
end


function dehilite_blocks(handles)
if isfield(handles, 'HiliteBlocks')
    for i=1:numel(handles.HiliteBlocks)
        try
            hilite_system(handles.HiliteBlocks(i), 'off');
        end
    end
end


function varobjs = load_data(handles)
listtable = get(handles.listtable,'data');
varobjs = [];
fileidx = [];
% process only the selected variables in the UI table
for i=1:size(listtable,1)
    [varobj, fidx] = getvarobject(listtable{i,3}, handles.VarTable);
    varobjs = [varobjs; varobj];
    fileidx = [fileidx; fidx];
end
% first categorize the variables into involved files to avoid load the same
% file several times against different variable
filesel = unique(fileidx);
for i=1:numel(filesel)
    % waitbar
    subvarobjs = varobjs(fileidx==filesel(i)); % get variables from the same file
    handles.DataFiles{filesel(i)}.LoadData({subvarobjs.Name});
end


%----------
function cfgmodel_general(handles)
% tbldata=get(handles.listtable,'Data');
currvarobjs = load_data(handles); % load data used for current signal selection
% process sample rate
currvarobjs.CalcSampleRate; % update the sample time if necessary
tmpsts = [currvarobjs.SampleRate];
st = min(tmpsts(tmpsts>0));
if get(handles.chkbox_sampletime,'Value')
    st=str2double(get(handles.edit_st,'String'));
else
    set(handles.edit_st,'String',num2str(st));
end
% process time range
trngs = vertcat(currvarobjs.TimeRange);
tstart = min(trngs(:,1));tend = max(trngs(:,2));
if get(handles.tRangeEn,'Value')
    t1=str2double(get(handles.edit_tStart,'String'));
    t2=str2double(get(handles.edit_tEnd,'String'));
    if isempty(t1)||isempty(t2)||t1<(tstart-100*st)||t2>(tend+100*st) %"100*StMin" as tolerance
        errordlg('Invalid time range.\n Proposed range: %f - %f',tstart,tend);
        return;
    else
        tstart = t1;
        tend = t2;
    end
else
    set(handles.edit_tStart,'String',num2str(tstart));
    set(handles.edit_tEnd,'String',num2str(tend));
end
% create timeseries variables
tsarr = [];
tref = tstart:st:tend; % uniform time
for i=1:numel(currvarobjs)
    if ~isempty(currvarobjs(i).Data)
        tstmp = timeseries(currvarobjs(i).Data, currvarobjs(i).Time, 'Name', currvarobjs(i).Name);
    else
        tstmp = timeseries(zeros(numel(currvarobjs(i).Time),1), currvarobjs(i).Time, 'Name', currvarobjs(i).Name);
    end
    tstmp = tstmp.setinterpmethod(currvarobjs(i).InterpMethod);
    if tstmp.Length>1
        tstmp = tstmp.resample(tref);
    end
    tsarr=[tsarr; tstmp];
end
% set model block parameter
% Set output dataype of all inports to double
inports=find_system(bdroot(gcs),'FindAll','on','SearchDepth',1,'BlockType','Inport');
for i=1:numel(inports)
    if islogical(tsarr(i).Data)
        set_param(inports(i),'OutDataTypeStr','boolean');
    else
        set_param(inports(i),'OutDataTypeStr',class(tsarr(i).Data));
    end
    set_param(inports(i),'PortDimensions',int2str(size(tsarr(i).Data,2)));
    if strcmp(tsarr(i).getinterpmethod, 'linear')
        set_param(inports(i),'Interpolate', 'on');
    else
        set_param(inports(i),'Interpolate', 'off');
    end
end
%Set model configuration
cfg=getActiveConfigSet(handles.CurrentModel);
cfg.Components(1).SolverType='Fixed-step';
cfg.Components(1).Solver='FixedStepDiscrete';
cfg.Components(1).StartTime=num2str(tstart);
cfg.Components(1).StopTime=num2str(tend);
cfg.Components(1).FixedStep=num2str(st);

assignin('base','Simport_externalinput_tsarray',tsarr);
extinputstr = sprintf('Simport_externalinput_tsarray(%u),', 1:numel(tsarr));
cfg.Components(2).ExternalInput = extinputstr(1:end-1); % remove the trailing ","

cfg.Components(2).LoadExternalInput='on';
cfg.Components(2).MaxDataPoints=num2str(numel(tref)+100);



% mdlwrkspace=get_param(handles.CurrentModel,'ModelWorkspace');
% mdlwrkspace.assignin('DataFileName',sprintf('%s;',handles.DataFileName{:}));
% mdlwrkspace.assignin('TimeRange',sprintf('%s - %s',cfg.Components(1).StartTime,cfg.Components(1).StopTime));

% --------------------------------------------------------------------
function setmodelcfg_ClickedCallback(hObject, eventdata, handles)
% hObject    handle to setmodelcfg (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isempty(handles.DataFiles)
    msgbox('No data file has been loaded.');
    return;
end
cfgmodel_general(handles);
msgbox('Off-line Simulink context has been established using test data','Completed');

% --------------------------------------------------------------------
function matchmodel_ClickedCallback(hObject, eventdata, handles)
% hObject    handle to matchmodel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
sych_portname_with_varname(handles);

% --------------------------------------------------------------------
function PinOnTop_ClickedCallback(hObject, eventdata, handles)
% hObject    handle to PinOnTop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
tmp=get(hObject,'CData');
set(hObject,'CData',get(hObject,'UserData'));
set(hObject,'UserData',tmp);
% Get JavaFrame of Figure.
warning('off','MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
fJFrame = get(handles.Simport,'JavaFrame');
if verLessThan('matlab', '7.10')
    figclient='fFigureClient';
elseif verLessThan('matlab', '8.4')
    figclient = 'fHG1Client';
else
    figclient = 'fHG2Client';
end
% Set JavaFrame Always-On-Top-Setting.
if strcmpi(get(hObject,'State'),'on')
    fJFrame.(figclient).getWindow.setAlwaysOnTop(1);
else
    fJFrame.(figclient).getWindow.setAlwaysOnTop(0);
end
warning('on','MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');


% --- Executes on button press in tRangeEn.
function tRangeEn_Callback(hObject, eventdata, handles)
% hObject    handle to tRangeEn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of tRangeEn
if get(hObject,'Value')
    set(handles.edit_tStart,'Enable','on');
    set(handles.edit_tEnd,'Enable','on');
else
    set(handles.edit_tStart,'Enable','off');
    set(handles.edit_tEnd,'Enable','off');    
end


function edit1_Callback(hObject, eventdata, handles)
% hObject    handle to edit1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit1 as text
%        str2double(get(hObject,'String')) returns contents of edit1 as a double


% --- Executes during object creation, after setting all properties.
function edit1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_tStart_Callback(hObject, eventdata, handles)
% hObject    handle to edit_tStart (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_tStart as text
%        str2double(get(hObject,'String')) returns contents of edit_tStart as a double


% --- Executes during object creation, after setting all properties.
function edit_tStart_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_tStart (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit_tEnd_Callback(hObject, eventdata, handles)
% hObject    handle to edit_tEnd (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_tEnd as text
%        str2double(get(hObject,'String')) returns contents of edit_tEnd as a double


% --- Executes during object creation, after setting all properties.
function edit_tEnd_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_tEnd (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end




% --------------------------------------------------------------------
function listtable_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to listtable (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function btn_cfg_ClickedCallback(hObject, eventdata, handles)
% hObject    handle to btn_cfg (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% path=fileparts(mfilename('fullpath'));
% open([path,'\Simport Guideline.pdf']);
SimportConfigFile(handles.DataFiles);


function sych_portname_with_varname(handles)
if ~isfield(handles,'VarTable')||isempty(handles.VarTable)
    return;
end
%Set selection list
vartable = handles.VarTable;
varlist = vartable(:,1);
%
inports=find_system(bdroot(gcs),'FindAll','on','SearchDepth',1,'BlockType','Inport');
tbldata=get(handles.listtable,'Data');
%
for i=1:numel(inports)
    portname=get_param(inports(i),'Name');
    idxmatch = strcmp(portname,varlist);
    if any(idxmatch)
        varobj = getvarobject(portname, vartable);
        tbldata{i,1}=['#', getdescriptor(varobj)];
        if sum(idxmatch)>1
            tbldata{i,3}=[portname, '@1']; % select 1st by default if multiple variable exist
        else
            tbldata{i,3}=portname;
        end
        tbldata{i,4}=strcmp(varobj.InterpMethod, 'linear');
        handles.HiliteBlocks = [handles.HiliteBlocks; inports(i)];
        hilite_system(inports(i),'find');
    else
    end
end
set(handles.listtable,'Data',tbldata);
if all(strncmp(tbldata(:,1),'#',3))
    fprintf(2, '##Simport: All ports auto-matched with variables in data file.\n');
end
guidata(handles.Simport, handles);


% --------------------------------------------------------------------
function updatecal_inca_ClickedCallback(hObject, eventdata, handles)
% hObject    handle to updatecal_inca (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
NF_INCA=SyncINCA(GetCalibrationVars(gcs));
if ~isempty(NF_INCA)
    wrnmsg=[{'The following variables not found as calibration value in INCA:'};{NF_INCA.CalName}'];
    warndlg(wrnmsg);
    fprintf(2, '\n#Simport# The following variables not found as calibration value in INCA\n');
    fprintf(2, '#Simport# %s\n',NF_INCA.CalName);
end




% --------------------------------------------------------------------
function dtconvert_ClickedCallback(hObject, eventdata, handles)
% hObject    handle to dtconvert (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
inports=find_system(bdroot(gcs),'FindAll','on','SearchDepth',1,'BlockType','Inport');
for i=1:numel(inports)
    lns=get_param(inports(i),'LineHandles');
    if lns.Outport>0
        bCnnted=1;
        lnnam=get_param(lns.Outport,'Name');
        lnpts=get_param(lns.Outport,'Points');
        delete_line(lns.Outport);
    end
    pt=get_param(inports(i),'PortHandles');
    pt=pt.Outport;
    basepos=get_param(pt,'Position');
    dtconv=add_block('built-in/DataTypeConversion',[bdroot(gcs),'/DataTypeConversion'],'MakeNameUnique', 'on','ShowName','off','Position',[basepos(1)+50,max(basepos(2)-8,0),basepos(1)+50+75,basepos(2)+8]);
    dtconvpt=get_param(dtconv,'PortHandles');
    ln1=add_line(bdroot(gcs),pt,dtconvpt.Inport,'autorouting','on');
    ptpos=get_param(dtconvpt.Outport,'Position');
    if bCnnted
        ln2=add_line(bdroot(gcs),[ptpos;lnpts(end,:)]);
        set_param(ln2,'Name',lnnam);
    end
end


% --- Executes on button press in chkbox_sampletime.
function chkbox_sampletime_Callback(hObject, eventdata, handles)
% hObject    handle to chkbox_sampletime (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of chkbox_sampletime
if get(hObject,'Value')
    set(handles.edit_st,'Enable','on');
else
    set(handles.edit_st,'Enable','off');  
end


function edit_st_Callback(hObject, eventdata, handles)
% hObject    handle to edit_st (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_st as text
%        str2double(get(hObject,'String')) returns contents of edit_st as a double


% --- Executes during object creation, after setting all properties.
function edit_st_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_st (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes when user attempts to close Simport.
function Simport_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to Simport (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: delete(hObject) closes the figure
% dehilite_blocks(handles);
delete(hObject);


% --- Executes during object deletion, before destroying properties.
function Simport_DeleteFcn(hObject, eventdata, handles)
% hObject    handle to Simport (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes when Simport is resized.
function Simport_ResizeFcn(hObject, eventdata, handles)
% hObject    handle to Simport (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in btn_refreshmodel.
function btn_refreshmodel_Callback(hObject, eventdata, handles)
% hObject    handle to btn_refreshmodel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
refresh_model(handles, 'normal');


% --------------------------------------------------------------------
function openfile_ClickedCallback(hObject, eventdata, handles)
% hObject    handle to openfile (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
importfile(handles, 'replace'); % import and update
