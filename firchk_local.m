% FIRCHK   Check if specified filter order is valid.
function [N,msg1,msg2,msgObj] = firchk_local(N,Fend,a,exception) %#codegen

%   Copyright 2000-2018 The MathWorks, Inc.

%   FIRCHK(N,Fend,A) checks if the specified order N is valid given the
%   final frequency point Fend and the desired magnitude response vector A.
%   Type 2 linear phase FIR filters (symmetric, odd order) must have a
%   desired magnitude response vector that ends in zero if Fend = 1.  This
%   is because type 2 filters necessarily have a zero at w = pi.
%
%   If the order is not valid, a warning is given and the order
%   of the filter is incremented by one.
%
%   If A is a scalar (as when called from fircls1), A = 0 is
%   interpreted as lowpass and A = 1 is interpreted as highpass.
%
%   FIRCHK(N,Fend,A,EXCEPTION) will not warn or increase the order
%   if EXCEPTION = 1.  Examples of EXCEPTIONS are type 4 filters
%   (such as differentiators or hilbert transformers) or non-linear
%   phase filters (such as minimum and maximum phase filters).


narginchk(3,4);

if nargin == 3
    exception = false;
end
    msg1 = '';
    msg2 = '';
    
if coder.target('MATLAB') % for MATLAB Execution    
    msgObj = [];   
else
    msgObj = zeros(0,1);
end

if isempty(N) || length(N) > 1 || ~isnumeric(N) || ~isreal(N) || N~=round(N) || N<=0
    [msg1, msgObj] = constructErrorObj("error",'signal:firchk:NeedRealPositiveOrder');    
    return;
end
 
if (a(end) ~= 0) && Fend == 1 && isodd(N) && ~exception
    [msg2, msgObj] = constructErrorObj("warning",'signal:firchk:NeedZeroGain');
    N = N + 1;
end

end

function [msg,msgobj] = constructErrorObj(errorType,varargin)
% constructErrorObj : constructs the required error object based on the
% target and error type. Type can be warning or error.
    if coder.target('MATLAB')
        msgobj = message(varargin{:});
        msg = getString(msgobj);
    elseif errorType == "error"
        msgobj = [];
        msg = '';
        coder.internal.error(varargin{:});
        return;
    elseif errorType == "warning"
        msgobj = [];
        msg = '';
        coder.internal.warning(varargin{:});
        return;    
    end

end
