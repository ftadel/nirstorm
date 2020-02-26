function varargout = process_nst_iir_filter( varargin )

% @=============================================================================
% This software is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2013 Brainstorm by the University of Southern California
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPL
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Authors: Thomas Vincent (2015-2016)

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    %TOCHECK: how do we limit the input file types (only NIRS data)?
    sProcess.Comment     = 'Band-pass filter';
    sProcess.FileTag     = @GetFileTag; 
    sProcess.Category    = 'Filter';
    sProcess.SubGroup    = 'NIRS';
    sProcess.Index       = 1306; %0: not shown, >0: defines place in the list of processes
    sProcess.isSeparator = 1;
    sProcess.Description = 'http://neuroimage.usc.edu/brainstorm/Tutorials/NIRSDataProcess';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'raw'}; %TODO: check processing of link to raw data
    % Definition of the outputs of this process
    sProcess.OutputTypes = {'data', 'data'}; %TODO: 'raw' -> 'raw' or 'raw' -> 'data'?
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    % Definition of the options
    
    % === Channel types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'NIRS';
    sProcess.options.sensortypes.InputTypes = {'data', 'raw'};
    
    % ==== Parameters 
    sProcess.options.label1.Comment = '<BR><U><B>Filtering parameters</B></U>:';
    sProcess.options.label1.Type    = 'label';
    
    
    sProcess.options.option_filter_type.Comment = 'Filter type';
    sProcess.options.option_filter_type.Type    = 'combobox';
    sProcess.options.option_filter_type.Value   = {1, {'bandpass', 'lowpass', 'highpass'}};
    sProcess.options.option_filter_type.Hidden  = 1; % Maintain compatibility
    
    sProcess.options.option_keep_mean.Comment = 'Keep mean';
    sProcess.options.option_keep_mean.Type    = 'checkbox';
    sProcess.options.option_keep_mean.Value   = 1;
    
    sProcess.options.option_low_cutoff.Comment = 'Lower cutoff frequency (0=disable):';
    sProcess.options.option_low_cutoff.Type    = 'value';
    sProcess.options.option_low_cutoff.Value   = {0.01, '', 4};
    
    sProcess.options.option_high_cutoff.Comment = 'Upper cutoff frequency (0=disable):';
    sProcess.options.option_high_cutoff.Type    = 'value';
    sProcess.options.option_high_cutoff.Value   = {0.5, '', 4}; 
    
        % === Display properties
    %sProcess.options.display.Comment = {'process_bandpass(''DisplaySpec'',iProcess,sfreq);', '<BR>', 'View filter response'};
    %sProcess.options.display.Type    = 'button';
    %sProcess.options.display.Value   = [];
    

end

%% ===== GET OPTIONS =====
function [HighPass, LowPass,FilterType,KeepMean] = GetOptions(sProcess)
    HighPass = sProcess.options.option_low_cutoff.Value{1};
    LowPass  = sProcess.options.option_high_cutoff.Value{1};
    
    ftypes = sProcess.options.option_filter_type.Value{2};
    filter_type = ftypes{sProcess.options.option_filter_type.Value{1}};
    
    FilterType='bandpass';
    
    if (HighPass == 0 || isequal(filter_type,'lowpass')) 
        HighPass = [];
        FilterType='lowpass';
    end
    
    if (LowPass == 0 || isequal(filter_type,'highpass'))  
        LowPass = [];
        FilterType='highpass';
    end
    
    
    KeepMean = sProcess.options.option_keep_mean.Value;
end


%% ===== FORMAT COMMENT =====
function [Comment, fileTag] = FormatComment(sProcess)
    % Get options
    [HighPass, LowPass,FilterType] = GetOptions(sProcess);
    % Format comment
    
    switch FilterType
        case 'bandpass'
            Comment = ['Band-pass: ' num2str(HighPass) 'Hz-' num2str(LowPass) 'Hz'];
            fileTag = '_IIR-band';
        case 'highpass'
            Comment = ['High-pass: ' num2str(HighPass) 'Hz'];
            fileTag = '_IIR-high';
        case 'lowpass'
            Comment = ['Low-pass: ' num2str(LowPass) 'Hz'];
            fileTag = '_IIR-low';
    end
end

%% ===== GET FILE TAG =====
function fileTag = GetFileTag(sProcess)
    [Comment, fileTag] = FormatComment(sProcess);
end


%% ===== RUN =====
function sInputs = Run(sProcess, sInputs) %#ok<DEFNU>

    warning('Deprecated process: use Pre-process > Band-pass filter instead');

    % Get option values
    
    [low_cutoff, high_cutoff,filter_type,keep_mean] = GetOptions(sProcess);
    order = 3;
    fs = 1 / diff(sInputs.TimeVector(1:2)); 
    
    %TOCHECK: take care of bad channels here?
    % channels = in_bst_channel(sInputs.ChannelFile);
    nirs_filtered = Compute(sInputs.A', fs, filter_type, low_cutoff, ...
                            high_cutoff, order, keep_mean);
    sInputs.A = nirs_filtered';
    
    % File comment
    switch filter_type
        case 'bandpass'
            filterComment = ['band(' num2str(low_cutoff) '-' num2str(high_cutoff) 'Hz)'];
        case  'highpass'   
            filterComment = ['high(' num2str(low_cutoff) 'Hz)'];
        case 'lowpass'
            filterComment = ['low(', num2str(high_cutoff) 'Hz)'];
    end
    sInputs.CommentTag = filterComment;
    
    % Do not keep the Std field in the output
    if isfield(sInputs, 'Std') && ~isempty(sInputs.Std)
        sInputs.Std = [];
    end
    
end


%% ===== Compute =====
function [nirs_filtered] = Compute(nirs_sig, fs, filter_type, low_cutoff, ...
                                  high_cutoff, order, keep_mean)
%% Apply Zero-phase Infinite Impulse filtering (Butterworth) on NIRS data.
%
% Args
%    - nirs_sig: matrix of double, size: time x nb_channels 
%        nirs signals to be filtered
%    - filter_type: str], choice in {'bandpass'} default: 'bandpass'
%        type of filter to apply
%    - low_cutoff: double
%        Lower frequency boundary for the filter
%    - high_cutoff: double
%        Higher frequency boundary for the filter
%    - keep_mean: int
%        If 0, then substract the signal mean (remove flat trend)
%
% Output:
%    - nirs_detrend: matrix of double, size: time x nb_channels 
%        detrended nirs signals

data = double(nirs_sig);


% Remove the mean before filtering    
if keep_mean
    nSamples = size(data,1);
    meanMatrix = repmat(mean(data),nSamples,1);
    
    data= data-meanMatrix;
end    
    
switch filter_type
    % HP filtering
    case 'highpass'
        [b,a]= butter(order,low_cutoff*2/fs, 'high');
        nirs_filtered = filtfilt(b,a,data);

    % LP filtering
    case 'lowpass'
        [b,a]= butter(order,high_cutoff*2/fs, 'low');
        nirs_filtered = filtfilt(b,a,data);

    % BP filtering
    case 'bandpass'
        [b,a]= butter(order,[low_cutoff*2/fs high_cutoff*2/fs]);
        nirs_filtered = filtfilt(b,a,data);

    case 'bandstop'
        [b,a]= butter(order,[low_cutoff*2/fs high_cutoff*2/fs], 'stop');
        nirs_filtered = filtfilt(b,a,data); 
end

% Add the mean back
if keep_mean
    nirs_filtered=nirs_filtered+meanMatrix;
end
    
end
