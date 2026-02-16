classdef DSPState < handle
    % DSPState  Handle class holding the DSP / GUI state (converted from S struct)
    
    properties
        %% 基本采样率/信号源
        fs = 44100;                    % 当前使用的采样率
        audioFs = 44100;               % 音频信号源采样率
        mtFs = 44100;                  % 多频正弦信号源采样率
        wsFs = 44100;                  % workspace 信号的采样率（通过 t 计算或用户直接指定采样率）
        currentSignal = [];            % 当前使用的信号
        audioSignal = [];              % 音频信号源数据
        multiToneSignal = [];          % 多频正弦信号源数据
        wsSignal = [];                 % 从 workspace 导入的信号
        timeDim = [];                  % 沿数据运算的维度
        wsTimeDim = [];                % workspace 信号的沿数据运算的维度
        noisy = [];                    % 加噪声后的信号
        filtered = [];                 % 滤波处理后的信号
        filter_b = [];                 % 滤波器分子系数 b
        filter_a = [];                 % 滤波器分母系数 a
        addNoise = false;              % 噪声仿真启用与否
        noiseTargetSNR = 20;           % 噪声仿真白噪声初始SNR值
        actualIIROrder = [];           % 实际 IIR 阶数，用于备注显示（用户自定义阶数<=0时，将记录自动估算的阶数）
        actualFIROrder = [];           % 实际 FIR 阶数，用于备注显示（用户自定义阶数<=0时，将记录自动估算的阶数）
        %% 音频播放器、录音与状态
        playerOrig = [];               % 原始/加噪音频播放器
        playerFilt = [];               % 处理后音频播放器
        % 录音对象和状态
        recorder = [];
        isRecording = false;
        % 状态标志（用于"保存录制/生成/加噪音频"按钮逻辑）
        hasRecorded = false;           % 是否有用户录制的音频（完成录制）
        loadedFromFile = false;        % 当前音频是否是用户"加载"的（来自文件）
        hasGenerated = false;          % 是否已生成多频正弦（onMTGenerate 成功后 true）
        noiseConfirmed = false;        % 是否已通过"确定"生成并应用了噪声（onNoiseConfirm）
        % 频率关系不对时弹出的提示窗口中添加一个"以后不再提示"的选项，disableAdjustAlert用于保存用户的选择
        disableAdjustAlert = false; 
        
        %% 继续滤波状态
        filteredHistory = {};          % 每次滤波后的信号，按时间顺序保存（cell array）
        filterHistory = {};            % 每次对应的滤波器系数，元素为 struct('b',b,'a',a)
        continueFilterCount = 0;       % 已进行的"继续滤波"次数
        continueFilterMax = 3;         % 最多允许的继续滤波次数（可调整）
        continueFilterMode = false;    % 是否处于"继续滤波"模式（由按钮启用）
        continueFilterPending = false; % 用户点击了"继续滤波"，等待下一次 Apply 来执行
        % ----- 继续滤波扩展：基准与临时试验结果 -----
        continueFilterBase = [];       % 当用户点击 Continue 时，把历史最后一条复制到这里作为"基准"
        continueTempLatest = [];       % 在同一基准下多次重新设计+Apply 产生的临时结果（不入历史）
        continueBaseIndex = 0;         % 基准在 history 中的索引（便于追踪）
        % Plot handles for legends
        filteredPlotHandlesTime = {};  % cell array of line/stem handles for time-axis (history)
        filteredPlotHandlesSpec = {};  % cell array of line/stem handles for spec-axis (history)
        continueTempHandleTime = [];   % handle for the current temporary result on time axis
        continueTempHandleSpec = [];   % handle for the current temporary result on spec axis
        % 控制：是否允许在 Apply 时重新启用 Continue（当达到上限后阻止 Apply 恢复）
        allowEnableContinueOnApply = true;  % 默认允许（正常流程下 Apply 会启用 Continue）
        % 是否允许应用滤波器按钮（当达到继续滤波上限后置为 false）
        allowApplyFilter = true;       % 默认允许
        filterIsDesigned = false;      % 启动时未设计滤波器 -> Apply 灰显
    
        %% 导出数据到工作区 
        audioOrigFs = [];                % 文件原始采样率
        audioOrignalSignal = [];         % 原始音频数据
        audioFileName = [];              % 音频文件名，例如 'speech.wav'
        audioFilePath = [];              % 音频文件所在路径
        % --- 多频正弦 ---
        mtFreqs = [];                    % 频率向量（Hz）
        mtAmps  = [];                    % 幅值向量（对应每个频率）
        mtN     = [];                    % 采样点数
        mtOrigFs = [];                   % 生成时的原始采样率（重采样前）
        multiToneOrignalSignal = [];     % 生成时的原始数据（重采样前）
        % --- 导入工作区数据 ---
        wsTime = [];                     % 时间向量（导入的 或 根据采样率生成的）
        wsTimeVarName = [];              % 时间向量变量名
        wsVarName = [];                  % 信号数据变量名
        wsOrigFs = [];                   % 原始采样率（重采样前）
        fromWorkspaceOrignalSignal = []; % 原始从 workspace 读取的未修改数据 
        hasResampled = false;            % 是否有效重采样标志
        filter_sos = [];                 % 滤波器的SOS结构

        %% 备用容器（用于动态字段/临时键值）
        misc = struct();  % 如果你有动态 field（以前用 S.(name)），建议放这里
    end

    methods
        function obj = DSPState()
            % constructor: properties already initialized above
        end

        function resetContinueFilterState(obj)
            % 清除内部 continue-filter 相关状态（保持 GUI 句柄清除留给 UI 层）

            % 清除继续滤波的历史与计数（不改变最原始数据 S.currentSignal / S.noisy）
            obj.filteredHistory = {};
            obj.filterHistory = {};
            obj.continueFilterCount = 0;
            obj.continueFilterMode = false;
            obj.continueFilterPending = false;
            obj.continueFilterBase = [];
            obj.continueTempLatest = [];
            obj.continueBaseIndex = 0;
            obj.filtered = []; % 最近一次结果也清空
            % 清除保存的绘图句柄
            obj.filteredPlotHandlesTime = {};
            obj.filteredPlotHandlesSpec = {};
            obj.continueTempHandleTime = [];
            obj.continueTempHandleSpec = [];
            % 允许后续 Apply / Continue 被重新启用（因为原始信号已改变）
            obj.allowEnableContinueOnApply = true;
            obj.allowApplyFilter = true;
            % 改变原始信号后，之前的滤波器设计失效 -> 需要重新设计
            obj.filterIsDesigned = false;  
        end

        function st = toStruct(obj)
            % 将对象状态导出为 struct（便于 save/assignin 等）
            p = properties(obj);
            st = struct();
            for k = 1:numel(p)
                st.(p{k}) = obj.(p{k});
            end
        end

        function newObj = clone(obj)
            % 简单的深拷贝（为避免引用共享时使用）
            newObj = DSPState();
            p = properties(obj);
            for k = 1:numel(p)
                newObj.(p{k}) = obj.(p{k});
            end
        end
    end
end
