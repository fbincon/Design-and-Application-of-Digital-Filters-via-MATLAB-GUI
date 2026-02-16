%% ========================================================================

% ----------- 向 firpm 传入该 firpm_fresp_example 的方式示例 --------------
% -------------------------------------------------------------------------
%   % 简单低通例子
%   f = [0 0.4 0.5 1]; 
%   W = [10 1];
%   N = 30;
%   % 方式 A: 直接传函数句柄
%   b = firpm(N, f, {@firpm_fresp_example}, W);
% 
%   % 方式 B: 精确幅度
%   A = [2 2 0 0]; 
%   b = firpm(N, f, {@firpm_fresp_example, A}, W);
%   b = firpm(N, f, {@firpm_fresp_example, 'A',A}, W);
%
%   % 获取 res 做诊断
%   [b,err,res] = firpm(N, f, {@firpm_fresp_example,A}, W);
%   [b,err,res] = firpm(N, f, {@firpm_fresp_example,'A',A}, W);
%
%   plot(res.fgrid, abs(res.error)); title('error on grid');

% -------------------------------------------------------------------------


function [DH, DW] = firpm_fresp_example(N, F, GF, W, varargin)
%FIRPM_FRESP_EXAMPLE  FIRPM 的示例频率响应函数（支持位置参数与 Name-Value）
%
% 用法：
%   % 位置参数（向后兼容）
%   [DH,DW] = firpm_fresp_example(N, F, GF, W)
%   [DH,DW] = firpm_fresp_example(N, F, GF, W, A)
%   [DH,DW] = firpm_fresp_example(N, F, GF, W, A, diff_flag)
%
%   % Name-Value（或混合）形式
%   [DH,DW] = firpm_fresp_example(N, F, GF, W, 'A', A, 'DiffFlag', df, 'Type', 'even')
%
%   % FIRPM 风格的 defaults 查询（两种形式均支持）
%   sym = firpm_fresp_example('defaults')
%   sym = firpm_fresp_example('defaults', {N, F, [], W, 'Type', 'odd', 'A', A})
%
% 输入：
%   N         - 滤波器阶数（标量）
%   F         - 频带边界向量，归一化到 [0,1]，长度须为偶数（成对出现）
%   GF        - 由 FIRPM 提供的网格频率向量（归一化，0..1）
%   W         - 每带权值（标量或长度为 nbands 的向量，nbands = length(F)/2）
%   可选（位置或 Name-Value）：
%     A or 'A'        - 幅度向量（与 F 等长）；若为空则自动生成交替阻/通带
%     diff_flag or 'DiffFlag' - 逻辑/0|1，微分器情形：若为 1 则在非零幅度带上按 1/f 调整权值（默认 0）
%     'Type' or 'Symmetry'    - 'even' 或 'odd'，仅用于 defaults 查询时指示对称性（默认 'even'）
%
% 输出：
%   DH        - 在网格 GF 上的期望频率响应（向量，长度等于 GF）
%   DW        - 在网格 GF 上的优化权值（向量，长度等于 GF）
%
% 说明：
%   - 本函数兼容 FIRPM 的 function-function 接口，可作为第三个参数传入 firpm：
%       b = firpm(N, F, {@firpm_fresp_example, ...}, W);
%   - 当 diff_flag 为真且某频带的期望幅度非零时，函数在该频带的每个网格点
%     将权值按 1/f（即 DW = W ./ max(GF, eps)）缩放，以模拟 MATLAB 官方 firpmfrf 的做法；
%     对 GF==0 使用 eps 做下限以避免除零。
%   - 若未提供幅度向量 A，函数会基于 F 自动生成交替的阻带/通带幅度，并发出警告。
%   - Name-Value 参数不区分大小写；若同时以位置参数和 Name-Value 给出同一选项，
%     位置参数优先覆盖 Name-Value。
%
% 示例：
%   % 低通示例（位置参数）
%   F = [0 0.3 0.4 1]; W = [10 1]; N = 30;
%   b = firpm(N, F, {@firpm_fresp_example}, W);
%
%   % 显式给出幅度并用 Name-Value
%   A = [0 0 1 1]; b = firpm(N, F, {@firpm_fresp_example, 'A', A}, W);
%
%   % 微分器情形（使用 DiffFlag，使非零幅度带按 1/f 加权）
%   b = firpm(44, [0 .3 .4 1], {@firpm_fresp_example, 'DiffFlag', 1}, [1 1]);
%
% 参考：
%   MATLAB 文档中关于 FIRPM / firpmfrf 的说明（function-function 接口与微分器权值策略）
%
% 日期：2026-01-19


% ------------------ 处理 'defaults' 查询 ------------------
if nargin >= 1 && ischar(N) && strcmpi(N, 'defaults')
    % 如果调用者提供第二个参数为 cell 数组，则把它视为 FIRPM 打包传入的参数：
    % 解析该打包参数以决定对称性（'even' 或 'odd'）。
    defaultSym = 'even';
    if nargin >= 2 && iscell(F) && ~isempty(F)
        packed = F; % 重用变量名 F 存放打包参数
        for k = 1:2:length(packed)
            if k+1 <= length(packed)
                key = packed{k}; val = packed{k+1};
                if ischar(key) && strcmpi(key, 'type')
                    if ischar(val)
                        if any(strcmpi(val, {'odd', 'even'}))
                            defaultSym = lower(val);
                        end
                    end
                end
            end
        end
    end
    DH = defaultSym;
    return;
end

% ------------------ 验证必需的位置参数 ------------------
if nargin < 4
    error('firpm_fresp_example:NotEnoughInputs', 'At least N, F, GF and W must be provided in a regular call.');
end

% 默认选项值
opts.A = [];
opts.DiffFlag = 0;   % 默认：不是微分器
opts.Type = 'even';  % 仅对 'defaults' 查询相关

% 检测位置形式提供的额外参数（向后兼容）
posA = [];
posDiff = [];
if ~isempty(varargin)
    if ~ischar(varargin{1}) && ~isstring(varargin{1})
        posA = varargin{1};
        if length(varargin) >= 2 && (~ischar(varargin{2}) && ~isstring(varargin{2}))
            posDiff = varargin{2};
            remaining = varargin(3:end);
        else
            remaining = varargin(2:end);
        end
    else
        remaining = varargin;
    end
else
    remaining = {};
end

% 解析剩余的 Name-Value 对
if ~isempty(remaining)
    if mod(length(remaining),2) ~= 0
        error('firpm_fresp_example:InvalidNameValue', 'Name-Value arguments must come in pairs.');
    end
    for k = 1:2:length(remaining)
        key = remaining{k}; val = remaining{k+1};
        if ~ischar(key) && ~isstring(key)
            error('firpm_fresp_example:InvalidName', 'Name must be a string.');
        end
        keyl = lower(char(key));
        switch keyl
            case {'a', 'amplitude'}
                opts.A = val;
            case {'diff_flag', 'diffflag'}
                opts.DiffFlag = logical(val);
            case {'type', 'symmetry'}
                if ischar(val) || isstring(val)
                    if any(strcmpi(val, {'even','odd'}))
                        opts.Type = lower(char(val));
                    else
                        error('firpm_fresp_example:InvalidType', 'Type must be ''even'' or ''odd''.');
                    end
                end
            otherwise
                warning('firpm_fresp_example:UnknownOption', 'Unknown option ''%s'' ignored.', keyl);
        end
    end
end

% 若提供了位置参数，则覆盖 Name-Value 中对应项
if ~isempty(posA)
    opts.A = posA;
end
if ~isempty(posDiff)
    opts.DiffFlag = logical(posDiff);
end

% 赋值为本地变量
A = opts.A;
diff_flag = double(opts.DiffFlag);

% ------------------ 基本校验 ------------------
if mod(length(F),2) ~= 0
    error('firpm_fresp_example:InvalidFreqVec', 'F must contain pairs of band edges (even length).');
end
% 可选：启用官方式的不连续性报错
for k=2:2:length(F)-2
    if F(k) == F(k+1)
        error('firpm_fresp_example:InvalidFreqVec', 'F contains repeated boundary bands (with zero-width frequency bands). F must be strictly increasing and appear in pairs.');
    end
end
nbands = length(F)/2;
if ~isscalar(W) && length(W) ~= nbands
    error('firpm_fresp_example:InvalidWeights', 'Length of W must equal number of bands (length(F)/2) or be scalar.');
end
if isscalar(W)
    W = repmat(W, 1, nbands);
end


% 若未提供 A，则自动生成交替的阻带/通带幅度向量
if isempty(A)
    A = zeros(1, length(F));
    if abs(F(1)) < eps
        is_pass = false;
    else
        is_pass = true;
    end
    for k = 1:nbands
        val = double(is_pass);
        A(2*k-1) = val;
        A(2*k)   = val;
        is_pass = ~is_pass;
    end
    warning('firpm_fresp_example:UsingDefaultA', 'No amplitude vector A provided. Using autogenerated alternating stop/pass A.');
end
if length(A) ~= length(F)
    error('firpm_fresp_example:InvalidDimensions', 'Length of F must equal length of A.');
end

% ------------------ 在 GF 网格上构建 DH 和 DW ------------------
DH = zeros(size(GF));
DW = zeros(size(GF));

f_eps = eps;   % 用于避免除零

l = 1;
for band = 1:nbands
    f1 = F(l); f2 = F(l+1);
    a1 = A(l); a2 = A(l+1);

    sel = (GF >= f1) & (GF <= f2);
    if ~any(sel)
        l = l + 2;
        continue;
    end

    % 期望响应：线性插值（与官方等价）
    if f2 ~= f1
        slope = (a2 - a1) / (f2 - f1);
        % 与官方使用 polyval 等价
        DH(sel) = a1 + slope * (GF(sel) - f1);
    else
        DH(sel) = 0.5 * (a1 + a2);
    end

    % 权值计算：严格模仿 firpmfrf 的行为
    % 官方使用: DW(sel) = W((l+1)/2) ./ (1 + (diff_flag & A(l+1) >= .0001)*(GF(sel)/2 - 1));
    % 若条件成立，分母化简为 GF/2，因此 DW = W / (GF/2) = 2*W ./ GF.
    % 这里按官方条件（阈值 1e-4）决定是否启用 1/f 加权，并对分母做下限保护。
    bandW = W(band);
    use_1_over_f = diff_flag && (a2 >= 1e-4);   % 和官方一致：检查上端点 a2
    if use_1_over_f
        % denom = GF/2 but 防止为 0
        denom = max(GF(sel)/2, f_eps);
        DW(sel) = bandW ./ denom;
    else
        DW(sel) = bandW;
    end

    l = l + 2;
end

end
