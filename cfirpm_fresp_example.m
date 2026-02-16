%% ========================================================================

% ----------- 向 cfirpm 传入该 cfirpm_fresp_example 的方式示例 --------------
% -------------------------------------------------------------------------
%    % 简单低通例子（使用内置参数）
%    f = [-1 -0.5 -0.4 0.4 0.5 1]; 
%    W = [1 1 10];
%    N = 30;
%    % 方式 A: 直接传函数句柄（额外 Name-Value 通过 cell 形式传入）
%    b = cfirpm(N, f, {@cfirpm_fresp_example, 'type','lowpass', 'd', 0}, W);
% 
%    % 方式 B: multiband 精确幅度（必须给 'a'）
%    a = [0 0 1 1 0 0]; % amplitudes at f band-edges
%    b = cfirpm(N, f, {@cfirpm_fresp_example, 'type','multiband', 'a', a}, W);
%    
%    % 获取 res 做诊断
%    [b,delta,res] = cfirpm(N, f, {@cfirpm_fresp_example, 'type','multiband','a',a}, W);
%    plot(res.fgrid, abs(res.error)); title('error on grid');


% 解释 defaults 调用：cfirpm 在开始设计前会调用 fresp('defaults', {N,f,[],W,...}) 来询问默认对称性（sym），
% 因此 fresp_example 在 'defaults' 分支里返回 'even'（或 'odd' 对于 Hilbert/differentiator）。
% 这能帮助 cfirpm 决定是否自动填充负频率部分。

% 如果你想更严格：可以把 fresp_example 的 a 参数要求为必须项（特别是 multiband），
% 并在函数中对 a 做更严格的尺寸检查。当前示例为了演示包含了对 a 缺失时的合理启发式行为。
% -------------------------------------------------------------------------




%% ========================================================================
% 以下为示例频率响应函数 cfirpm_fresp_example

function varargout = cfirpm_fresp_example(varargin)
% cfirpm_fresp_example  示例用户自定义 fresp，供 cfirpm 使用
%
% 用法（defaults 查询）:
%   sym = cfirpm_fresp_example('defaults', {N, f, [], W, 'type', type, 'a', a, 'd', d, ...})
%
% 用法（常规调用）:
%   [dh, dw] = cfirpm_fresp_example(N, f, gf, W, 'type', type, 'a', a, 'd', d, ...)
%
% 参数说明:
%   N     - 滤波器阶数（标量）
%   f     - 带边矢量（单调、位于 [-1,1]、偶数长度），与传入 cfirpm 的 f 相同
%   gf    - 频率网格（列向量，取值在 [-1,1]），仅在常规调用时使用
%   W     - 每带权重（长度 = length(f)/2），可为 [] 或省略
%
% 名称-值选项:
%   'type' - 可选: 'lowpass'(默认), 'highpass', 'bandpass', 'multiband',
%            'differentiator', 'hilbert', 'allpass'
%   'a'    - 当 type='multiband' 时使用的带边幅度向量（长度等于 length(f)）
%   'd'    - 组延迟偏移（标量，默认 0）。函数把幅度响应乘以 exp(-1j*pi*gf*N/2)，
%            若 d~=0 再乘以 exp(-1j*2*pi*d*gf)（总组延迟 = N/2 + d）
%   'fc'   - 截止频率（用于简单低通/高通，非必需）
%   'trans'- 过渡带宽（用于启发式处理，非必需）
%
% 输出:
%   dh  - 在 gf 点的期望复频响（列向量）
%   dw  - 在 gf 点的正实权重（列向量）
%
% 说明:
%  - 若未为多带设计提供精确的幅度向量 'a'，本示例会用简单启发式方法生成幅度。
%    若要精确控制多带设计，请传入 'a'。
%  - cfirpm 在开始设计前会调用本函数的 'defaults' 分支：
%    cfirpm_fresp_example('defaults', {N,f,[],W,...}) 用于获取默认对称性，因此
%    本函数实现了该分支。

% ------------------------ 处理 'defaults' 调用 -------------------------
if nargin >= 1 && ischar(varargin{1}) && strcmp(varargin{1}, 'defaults')
    % cfirpm 调用形式: fresp('defaults', {N,f,[],W,p1,p2,...})
    C = varargin{2}; % cell
    % 解包可用参数
    if ~iscell(C) || numel(C) < 2
        varargout{1} = 'none';
        return;
    end
    N = C{1}; f = C{2};
    % 其余可选参数（可能包含 'type','a','d', ...）
    extra = {};
    if numel(C) > 4
        extra = C(5:end);
    end
    % 获取 type（如果有）
    type = getParamFromCell(extra, 'type', 'lowpass');
    % 决定默认对称性：
    switch lower(type)
        case {'differentiator','hilbert'}
            sym = 'odd';
        otherwise
            sym = 'even';
    end
    varargout{1} = sym;
    return;
end

% ------------------------ 常规调用 ----------------------------------
% 签名: (N, f, gf, W, <NameValue...>)
% 最低参数检查
if nargin < 3
    error('cfirpm_fresp_example:TooFewInputs','至少需要 N, f, gf 三个输入。');
end
N  = varargin{1};
f  = varargin{2};
gf = varargin{3};
if nargin >= 4
    W = varargin{4};
    nvStart = 5;
else
    W = [];
    nvStart = 4;
end

% 收集名称-值对（如果有）
if nargin >= nvStart
    nv = varargin(nvStart:end);
else
    nv = {};
end
type  = getParamFromCell(nv, 'type', 'multiband');
a     = getParamFromCell(nv, 'a', []);   % 带边幅度（可选）
d     = getParamFromCell(nv, 'd', 0);    % 组延迟偏移
fc    = getParamFromCell(nv, 'fc', []);  % 可选截止频率覆盖
trans = getParamFromCell(nv, 'trans', 0.05);

% 确保列向量
gf = gf(:);

% 若 W 未给出，默认每带权重为 1（稍后映射到每个网格点）
nbands = numel(f)/2;
if isempty(W)
    W = ones(1, nbands);
end

% 根据 type / a 在 gf 上计算期望幅度 mags
switch lower(type)
    case 'lowpass'
        % 启发式：若提供 fc 则使用；否则从 f 中推断
        if ~isempty(fc)
            cutoff = abs(fc);
        else
            % 尝试推断截止：取第一个大于等于 0 的带边
            posEdges = f(f>=0);
            if isempty(posEdges)
                cutoff = 0.5;
            else
                % 启发式：选择第一个正带的第二个边界作为截止
                cutoff = posEdges(min(2,numel(posEdges)));
                if isempty(cutoff) || cutoff==0
                    cutoff = 0.5;
                end
            end
        end
        mags = zeros(size(gf));
        mags(abs(gf) <= cutoff) = 1;
        % 平滑线性过渡
        tmask = (abs(gf) > cutoff) & (abs(gf) <= cutoff + trans);
        mags(tmask) = linspace(1,0,sum(tmask));
    case 'highpass'
        if ~isempty(fc)
            cutoff = abs(fc);
        else
            posEdges = f(f>=0);
            if isempty(posEdges)
                cutoff = 0.5;
            else
                cutoff = posEdges(1);
                if isempty(cutoff) || cutoff==0
                    cutoff = 0.5;
                end
            end
        end
        mags = zeros(size(gf));
        mags(abs(gf) >= cutoff) = 1;
        tmask = (abs(gf) < cutoff) & (abs(gf) >= cutoff - trans);
        mags(tmask) = linspace(0,1,sum(tmask));
    case 'bandpass'
        % 若提供 a 且长度匹配则使用，否则采用启发式：选择包含 0 的带或中间带
        if ~isempty(a) && numel(a)==numel(f)
            mags = interp1(f(:), a(:), gf, 'linear', 0);
        else
            mags = zeros(size(gf));
            % 找到非负的带
            posBands = reshape(f,2,[]); posBands = posBands(:, all(posBands>=0));
            if ~isempty(posBands)
                lo = posBands(1,1); hi = posBands(2,1);
            else
                % 回退带
                lo = 0.2; hi = 0.4;
            end
            mags((gf>=lo) & (gf<=hi)) = 1;
        end
    case 'multiband'
        if isempty(a)
            % 若未提供 a，则简单交替 0/1（从第一个带为 0 开始）
            alt = repmat([0 1], 1, nbands/2 + 1);
            a = zeros(size(f));
            a(1:numel(a)) = alt(1:numel(a));
        end
        mags = interp1(f(:), a(:), gf, 'linear', 'extrap');
    case 'differentiator'
        % 微分器幅度 ~ |omega|（gf 在 -1..1，按比例处理）
        mags = abs(gf);
    case 'hilbert'
        mags = ones(size(gf));
        % Hilbert: 虚部为奇对称（±90°），这里通过 sign(gf) 在后续设置相位
    case 'allpass'
        mags = ones(size(gf));
    otherwise
        error('cfirpm_fresp_example:UnknownType','未知的 type "%s".', type);
end

% 构造复数期望响应 dh:
% 默认线性相位项：exp(-1j*pi*gf*N/2)
baseDelay = exp(-1j*pi*gf*(N/2 + d));


switch lower(type)
    case 'hilbert'
        % Hilbert 近似: dh = -1j*sign(gf)（正负频率分别为 ±90°）
        dh = mags .* (-1j * sign(gf)) .* baseDelay;
        % gf==0 处设为 0
        dh(gf==0) = 0;
    case 'differentiator'
        % 微分器是实值奇函数 -> mags * sign(gf) * 相位项
        dh = mags .* sign(gf) .* baseDelay;
    case 'allpass'
        % 全通：幅度为 1，但可以指定任意相位；这里使用 baseDelay
        dh = mags .* baseDelay;
    otherwise
        dh = mags .* baseDelay;
end

% 计算 dw：将每带的权重 W 映射到每个 gf 点
dw = ones(size(gf));
% 带由 f(1:2), f(3:4), ... 定义
for k = 1:nbands
    lo = f(2*k-1); hi = f(2*k);
    idx = (gf >= lo) & (gf <= hi);
    if any(idx)
        dw(idx) = W(k);
    end
end
% 安全处理：确保为正实权重
dw = real(dw);
% 若存在非法值或非正值，用一个合理的小正数或最小正值替代
if any(~isfinite(dw) | dw<=0)
    posvals = dw(isfinite(dw) & dw>0);
    if isempty(posvals)
        fallback = eps;
    else
        fallback = min(1, max(eps, min(posvals)));
    end
    dw(~isfinite(dw) | dw<=0) = fallback;
end

% 输出
varargout{1} = dh(:);
if nargout >= 2
    varargout{2} = dw(:);
end

end

% ---------------------- 辅助函数：从 cell 中解析 名-值 ---------------------
function val = getParamFromCell(cellargs, name, default)
% 简单的名值解析，cellargs = {'name1', val1, 'name2', val2, ...}
val = default;
if isempty(cellargs), return; end
try
    cn = cellargs;
    % 若第一个元素是包含名值对的 cell（如 defaults 调用时），则展开
    if iscell(cn) && isscalar(cn) && iscell(cn{1})
        cn = cn{1};
    end
    for k=1:2:numel(cn)-1
        key = cn{k};
        if ~ischar(key) && ~isstring(key), continue; end
        if strcmpi(char(key), name)
            val = cn{k+1};
            return;
        end
    end
catch
    val = default;
end
end
