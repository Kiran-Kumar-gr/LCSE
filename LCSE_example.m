%%                Latent common source extraction (LCSE)
% LCSE seeks to construct a common latent representation of the SSVEP signal
% subspace that is stable across multiple trials of EEG data.

% The spatial filter thus obtained improves the signal-to-noise ratio (SNR)
% of the SSVEP components by removing nuisance signals that are irrelevant
% to the generalized signal representation learnt from the given data.
%
%   This is a sample code for testing LCSE as described in the article
%   [1].
%   Use the SSVEP benchmark dataset placed in a folder in the same directory as this file
%% Dataset used: SSVEP benchmark dataset [2]
%   A 40-target SSVEP benchmark dataset recorded from 35 subject. The stimuli
%   were generated by the joint frequency-phase modulation (JFPM) [1]
%     - Stimulus frequencies    : 8.0 - 15.8 Hz with an interval of 0.2 Hz
%     - Stimulus phases         : 0pi, 0.5pi, 1.0pi, and 1.5pi
%     - No. of channels         : 64
%     - Selected channels       :9 electrodes[ 1(48): Pz, 2(54): PO5,
%                                  3(55):  PO3, 4(56): POz, 5(57): PO4,
%                                  6(58): PO6, 7(61): O1, 8(62): Oz,
%                                  and 9(63): O2)
%     - No. of recording blocks : 6
%     - Data length of epochs   : 6 s [ 0.5s cue, 5s data, 0.5s blank ]
%     - Sampling rate           : 250 [Hz]
%
%   Data is a 4-D matrix named "data" with dimensions of [64, 1500, 40, 6]
%   The four dimensions indicate,
%         [Electrode_index, Time_points, Target_index, Block_index]
%         
%          Sample data used here for demonstration is S1 data.
%
%% Required functions: LCSE
%  The function has been test only on the SSVEP benchmark dataset described in [2]
% [prediction, score] = LCSE(sampling_rate, train_data, test_data, 
%                            ...number_of_filterbank, 
%                            ...number_of_Reconstructed_channel);
% 
% Filter bank coefficients : a = 1.25; b = 0.25;  as defined in [1]
% 
% Specification of each input variables
% 
% -> sampling rate - EEG data sampling rate (integer value) 
% 
% -> train_data - data dimension -> [no. of channels, no. of EEG data points, 
%                                   ...no. of targets, no. of trial blocks]
%    constraints: no. of channels >=2
%                 no. of EEG data points >= 0.2s of data points
%                 no. of targets  >=2
%                 no. of trial blocks >=2
% 
% -> test_data - data dimension -> [no. of channels, no. of EEG data points, 
%                                   ...no. of targets]
%    constraints: the dimensions of test data should match the corresponding 
%    dimension in the train data
% 
% -> number_of_filterbank - should be a interger value between 1 and 7,
%    Refer [1] for further description
% 
% -> number_of_Reconstructed_channel - should be a interger value between 1 
%    and no. of trial blocks used for training, Refer [1] for further description
% 
%% Reference:
%   [1] Kiran Kumar G. R and Ramasubbareddy M, "Latent common source
%       extraction via a generalized canonical correlation framework for
%       frequency recognition in SSVEP based brain–computer interfaces," in
%         Journal of Neural Engineering.
%       doi: 10.1088/1741-2552/ab13d1
%   Visit my research gate page to download the preprint,
%       link : https://www.researchgate.net/profile/Kiran_Kumar_G_R
% 
%   [2] Y. Wang, X. Chen, X. Gao and S. Gao, "A Benchmark Dataset for
%       SSVEP-Based Brain–Computer Interfaces", in IEEE Transactions on
%       Neural Systems and Rehabilitation Engineering,
%       vol. 25, no. 10, pp. 1746-1752, Oct. 2017.
%%
% Author: Kiran Kumar G R
% Affiliation: Indian Institute of Technology Madras.
% email: kirankumar.g.r@hotmail.com
% Google Scholar: https://scholar.google.co.in/citations?user=fH96otoAAAAJ&hl=en
% Last revised : November 2019
% Please send suggestions/queries to the above email.
%------------------ BEGIN CODE-------------------------%
%% Clear workspace
clear all;
close all;
clc;
warning off;
%% Setting paths to the support functions and
% get data from the folder name data
addpath('data');
%% Variable parameters
% The various window lengths under test ->(0.2:0.2:1.4);
buffer_length=0.2;
% Number of reconstructed channels
Recon_channel=3;    % default number of reconstructed channels is 3
% The filter bank analysis on - 1 or off - 0
Filt_on = 'true';
% The number of sub-bands in filter bank analysis
tf=0;
tf=strcmpi(Filt_on,'true');
if tf==0
    num_filterbank = 1;
else
    % default number of filter-bank is 5
    num_filterbank = 5;
end
%% Parameter as used in [1]
fs = 250;                              % Hz % Sampling rate of EEG data
visual_delay = round(0.14*fs);          % Visual latency [140ms] in samples
% 0.5 s of visual cue {described in dataset [2]} + 0.14 s of delay,
start_trial = round(0.5*fs) + visual_delay;
% gaze shifting time [s] {described in dataset [2]}
gaze_shift_time = 2;
% List of targets frequencies
Target_ind = [8 : 15 , 8.2 : 15.2 , 8.4 : 15.4 , 8.6 : 15.6 , 8.8 : 15.8]; % Hz
num_Target = length(Target_ind);       % The number of stimuli
labels = 1 : num_Target;                 % Labels
% Channels as used in [1], Benchmark dataset paper and other recent articles
Chan_ind = [48, 54 : 58, 61 : 63];
% default number of reconstructed channels is a = 1.25; b = 0.25
%% SSCOR - implementation
% the SSVEP dataset placed with the data folder. Kindly change to suit the .mat file of your interest
% the code was tested using the SSVEP benchmark dataset [2].
filename = 'data.mat';
dat = matfile(filename);
data = dat.data;
% Extracting the required channels
data = data(Chan_ind , : , : , :);
[~ , ~ , ~ , block_number] = size(data);
% Initializing variables used
% Accuracy = zeros(length(buffer_length) , block_number);
% ITR = Accuracy;
acc = zeros(1 , block_number);
itrs = acc;
% Evaluation of the algorithm
% Buffer length used for target classification in seconds
gazing_time = buffer_length;
% Data length [samples]
len_gaze_smpl = round(gazing_time * fs);
segmented = ((start_trial)+1) : ((start_trial)+len_gaze_smpl);
% EEG segmentation
eeg_segment = data(: , segmented , : , :);
% Selection time [s]
Selection_time = gazing_time + gaze_shift_time;
% Evaluation across each block
for i = 1 : block_number
    % Training data
    data_train = eeg_segment;
    data_train(: , : , : , i) = [];
    % Testing data
    data_test = squeeze(eeg_segment(: , : , : , i));
    % LCSE function
    [prediction, score] = LCSE(fs, data_train, data_test, num_filterbank, Recon_channel);
    % Evaluation
    is_correct = (prediction == labels);
    acc(i) = mean(is_correct) * 100;
    accuracy=(acc(i)/100);
    if accuracy ==1
        itrs(i) = log2(length(labels))*60/Selection_time;
    else
        itrs(i) = (log2(length(labels)) + accuracy*log2(accuracy) + (1-accuracy)*log2((1-accuracy)/(length(labels)-1)))*60/Selection_time;
    end
 end 
% mean accuracy
Mean_acc=mean(acc)
% mean ITR 
Mean_ITR=mean(itrs)
