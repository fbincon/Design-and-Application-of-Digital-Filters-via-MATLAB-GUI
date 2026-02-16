classdef GUIHandles < handle
    % GUIHandles  Handle class to hold GUI controls and related containers.
    % Usage:
    %   handles = GUIHandles(); 
    %   % or handles = GUIHandles(initStruct) where initStruct has fields matching property names
    %
    % After creation you can still assign e.g. handles.btnPlayFilt = btnPlayFilt;

    properties
        % ---------- Data I/O & controls ----------
        ddDataSource
        lblFsValue
        btnRec
        ddRecMode
        edtRecDuration
        btnLoadAudio
        btnEditFs
        btnMT_Gen
        btnImportWS
        btnPlotSettings
        plotSettings = struct( ...
            'signalPlotMode', 'plot', ...
            'specFreqNormalized', false, ...
            'specFreqScale', 'linear', ...
            'specFreqSide', 'single', ...
            'specMagMode', 'dB', ...
            'specMagNormalized', false, ...
            'filterSpecNFFT', 8192 ...
        );

        % ---------- Filter design ----------
        ddDesignMethod
        ddIIRProto
        edtIIROrder
        edtFIROrder
        ddFIRMethod
        ddWindow
        lblDesignSelected

        % ---------- Filter params & history ----------
        ddType
        edtRp
        edtRs
        edtPb1
        edtPb2
        sldPb1
        sldPb2
        edtSb1
        edtSb2
        sldSb1
        sldSb2
        btnMultiBand
        multiBandParams = [];
        multiBandParamsHistory = [];
        yuleWalkParams = [];
        yuleWalkParamsHistory = {};
        maxflatParams = [];
        maxflatParamsHistory = {};
        fir2Params = [];
        fir2ParamsHistory = {};
        firpmParams = [];
        firpmParamsHistory = {};
        firpmMBPaHistory = [];
        firpmMBPaCal = [];
        cfirpmParams = [];
        cfirpmParamsHistory = {};
        firlsParams = [];
        firlsParamsHistory = {};
        firclsParams = [];
        firclsParamsHistory = {};
        fircls1Params = [];
        fircls1ParamsHistory = {};
        intfiltParams = [];
        intfiltParamsHistory = {};
        gaussdesignParams = [];
        gaussdesignParamsHistory = {};
        rcosdesignParams = [];
        rcosdesignParamsHistory = {};
        sgolayParams = [];
        sgolayParamsHistory = {};
        sgolay_Bmatrix = [];
        sgolay_Gmatrix = [];
        btnNotchPeakParams
        lblNotchPeak
        notchPeakParams = [];
        notchPeakParamsHistory = {};
        PeakOrder = [];
        NotchOrder = [];
        notchPeakFilters = [];

        % ---------- Noise simulation ----------
        cbAddNoise
        cbWhiteNoise
        cbToneNoise
        cbGaussNoise
        cbMultiTone
        edtNoiseSNR
        edtToneFreq
        edtToneAmp
        edtGaussStd
        edtMultiFreqs
        edtMultiAmp
        btnNoiseConfirm

        % ---------- Actions ----------
        btnContinue
        ddFilterFunction
        btnApply
        btnPlayOrig
        btnPlayFilt
        btnSaveFigs
        btnSaveFiltered
        btnSaveOrigGen
        btnExportDataToWS

        ddFilterAnalysis
        btnViewFilterAnalysis
        filterMetricsComponents = struct();
        filterMetricsFig = [];
        filterAnalyzerApp = [];
        groupDelayFig = [];
        groupDelayComponents = struct();
        impulseFig = [];
        impulseComponents = struct();
        phaseDelayFig = [];
        phaseDelayComponents = struct();
        pzFig = [];
        pzComponents = struct();
        stepRespFig = [];
        stepRespComponents = struct();

        btnShowCompare
        figCompare
        axCompare1
        axCompare2
        axCompare3
        axCompare4

        % ---------- Initial states (UI) ----------
        statusBar

        % ---------- Axes & info region ----------
        axOrigTime
        axOrigSpec
        axFiltTime
        axFiltSpec
        axFilterResp
        axFilterPhase
        ta_GUI
        btnHelp
        
        % ---------- any other misc fields ----------
        misc = struct();   % 可放置少量动态字段
    end

    methods
        function obj = GUIHandles(init)
            % Constructor: optional init struct to populate properties
            if nargin >= 1 && isstruct(init)
                fn = fieldnames(init);
                for k = 1:numel(fn)
                    name = fn{k};
                    if isprop(obj, name)
                        obj.(name) = init.(name);
                    else
                        % dynamic fields go to misc
                        obj.misc.(name) = init.(name);
                    end
                end
            end
        end

        function safeSetEnable(obj, name, val)
            % 安全设置控件 Enable 属性（obj = GUIHandles instance）
            if ~isprop(obj, name)
                return; % 没有该属性，直接返回
            end
            ctrl = obj.(name);
            if isempty(ctrl)
                return;
            end
            % 如果是 graphics / UI 控件，先检查 isvalid
            try
                if isvalid(ctrl)
                    try
                        ctrl.Enable = val;
                    catch
                        % 该控件可能没有 Enable 属性
                        % 可在此扩展支持不同控件类型（例如 uiaxes 没有 Enable）
                    end
                end
            catch
                % isvalid 在某些非 handle 值上会出错，尝试更通用的设置
                try
                    ctrl.Enable = val;
                catch
                    % 忽略
                end
            end
        end

        function v = getValueSafe(obj, name, defaultVal)
            % 返回控件的数值（double），兼容 struct-style dynamic fields 存在于 obj.misc
            if nargin < 3, defaultVal = []; end
            v = defaultVal;
            try
                % 1) 优先属性（对象中声明的属性）
                if isprop(obj, name)
                    ctrl = obj.(name);
                else
                    % 2) 回退到 misc（保留对动态字段的支持）
                    if isfield(obj.misc, name)
                        ctrl = obj.misc.(name);
                    else
                        return;
                    end
                end
    
                if isempty(ctrl)
                    return;
                end
    
                % ctrl 可能是 matlab graphics handle、App 对象、或简单数值
                if isa(ctrl, 'handle') && isvalid(ctrl)
                    % 优先使用 Value 属性（多数 UI 控件有）
                    if isprop(ctrl, 'Value')
                        val = ctrl.Value;
                    elseif isprop(ctrl, 'String') % 兼容文本
                        val = ctrl.String;
                    else
                        % 如果没有 Value/String，尝试直接返回对象（不转换）
                        v = defaultVal;
                        return;
                    end
                else
                    % ctrl 不是 handle（可能是数字或 struct），直接返回
                    val = ctrl;
                end
    
                % 尝试将数值转为 double（若合理）
                if isempty(val)
                    v = defaultVal;
                elseif isnumeric(val) || islogical(val)
                    v = double(val);
                elseif ischar(val) || isstring(val)
                    % 尝试数值化字符串
                    num = str2double(val);
                    if ~isnan(num)
                        v = double(num);
                    else
                        v = defaultVal;
                    end
                else
                    v = defaultVal;
                end
            catch
                v = defaultVal;
            end
        end
    
        function safeSetValPair(obj, edtName, sldName, value)
            % 同步设置 数值编辑框 与 滑块 的 Value（带边界保护）
            if nargin < 4, return; end
            names = {edtName, sldName};
            for k = 1:2
                nm = names{k};
                try
                    if isprop(obj, nm)
                        ctrl = obj.(nm);
                    elseif isfield(obj.misc, nm)
                        ctrl = obj.misc.(nm);
                    else
                        continue;
                    end
                    if isempty(ctrl), continue; end
                    if isa(ctrl, 'handle') && isvalid(ctrl) && isprop(ctrl,'Value') && isprop(ctrl,'Limits')
                        lims = ctrl.Limits;
                        v2 = max(lims(1), min(value, lims(2)));
                        ctrl.Value = v2;
                    elseif isstruct(ctrl) && isfield(ctrl,'Value') && isfield(ctrl,'Limits')
                        % 偶发情况：ctrl 存为结构（兼容性）
                        lims = ctrl.Limits;
                        v2 = max(lims(1), min(value, lims(2)));
                        ctrl.Value = v2;
                        % 如果希望写回 misc 中：
                        obj.misc.(nm) = ctrl;
                    else
                        % 其它类型：尝试直接赋值（无边界保护）
                        try
                            ctrl.Value = value;
                        catch
                            % 忽略
                        end
                    end
                catch
                    % 忽略单条失败
                end
            end
        end
        
        function safeSetText(obj, name, txt)
            if isprop(obj, name) && ~isempty(obj.(name)) && isvalid(obj.(name))
                try
                    if isprop(obj.(name),'String')
                        obj.(name).String = txt;
                    elseif isprop(obj.(name),'Text')
                        obj.(name).Text = txt;
                    end
                catch
                end
            end
        end

        function tf = isValidAll(obj)
            % 检查主要 UI 句柄是否仍然有效（示例）
            hf = obj.figCompare;
            tf = true;
            if ~isempty(hf) && ~isvalid(hf)
                tf = false;
            end
        end

        function clearUIRefs(obj)
            % 清除对 UI 句柄的引用（例如窗口关闭时）
            props = properties(obj);
            for k = 1:numel(props)
                p = props{k};
                v = obj.(p);
                % 如果是 graphics handle 或 app 对象，清空引用
                if isa(v, 'matlab.ui.Figure') || isa(v, 'matlab.ui.control.UIControl') || isa(v, 'matlab.graphics.axis.Axes') || isa(v, 'matlab.ui.componentcontainer.ComponentContainer')
                    obj.(p) = [];
                end
            end
            % 保留配置性的小 struct
            obj.filterMetricsComponents = struct();
            obj.filterMetricsFig = [];
        end

        function st = toStruct(obj)
            % 导出为 struct（注意：仍包含 uicontrol 对象引用）
            p = properties(obj);
            st = struct();
            for k = 1:numel(p)
                st.(p{k}) = obj.(p{k});
            end
        end

        function newObj = clone(obj)
            % 生成一个浅拷贝（属性值逐一拷贝）
            newObj = GUIHandles();
            p = properties(obj);
            for k = 1:numel(p)
                newObj.(p{k}) = obj.(p{k});
            end
        end
    end
end
