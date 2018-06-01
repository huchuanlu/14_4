%% Copyright (C) Shu Wang and Fan Yang.
%% All rights reserved.

% DESCRIPTION OF OPTIONS:
% Following is a description of the options you can adjust for
% tracking, each proceeded by its default value.
% *************************************************************
% For a new sequence , you will certainly have to change p.
% *************************************************************
% To set the other options,
% first try using the values given for one of the demonstration
% sequences, and change parameters as necessary.
% *************************************************************
% p = [px, py, sx, sy, theta]; 
% The location of the target in the first frame.
%      
% px and py are the coordinates of the center of the bounding box
%
% sx and sy are the size of the box in the x (width) and y (height)
% dimensions, before rotation
%
% theta is the rotation angle, which is currently set to 0.0 for all 
% sequences
%
% numsample: The number of samples used in the condensation
% algorithm/particle filter. Increasing this will likely improve the
% results, but make the tracker slower.
% 
% 'affsig',[4,4,.02,.02,.005,.001]: These are the standard deviations of
% the dynamics distribution, and it controls the scale, size and area to 
% sample the candidates.
% affsig(1) = x translation (pixels, mean is 0)
% affsig(2) = y translation (pixels, mean is 0)
% affsig(3) = rotation angle (radians, mean is 0)
% affsig(4) = x scaling (pixels, mean is 1)
% affsig(5) = y scaling (pixels, mean is 1)
% affsig(6) = scaling angle (radians, mean is 0)
%
% myopt.sigma_c and myopt.sigma_s are standard deviations for location 
% and scale, and are expected to penalize the change in location and scale.
%
% OTHER OPTIONS THAT COULD BE SET HERE:
% Change 'title' to choose the sequence you wish to run. If you set
% title to 'bird2', for example, then it expects to do test on sequence
% bird2.
% *************************************************************

%% compile interp_fast and SLIC or not
do_compile = 1;

%% names of sequences
title = 'bird2';

%% save images of tracking results or not 
dump_frames = true;
% dump_frames = false;  

%% parameters of motion model
myopt.grid_size = 64;         % the size of template for simple tracking in first several frames
myopt.grid_ratio = 1.5;       % namda_s which controls the size of surrounding region of the target. 1.5~2.2
myopt.train_frame_num = 4;    % simple tracking frame number for training
myopt.show_patch_num = 5;

%% training and superpixel parameter
train_sp_sum_num = 0;          % the summary number of all superpixels in training process
train_sum_hist=[];
train_sum_hist_index=[];
frame_num = 0;                  
offline_incre_num = 1;
update_flag = 0;
update_sp_sum_num = 0;

sp_index_pre = zeros(1,myopt.train_frame_num + 1);
sp_index_pre(1)=0;

myopt.HSI_flag = 1;                  % whether use HSI color space
myopt.ch_bins_num = 8;               % the number of bins every color channel possesses.
myopt.cluster_bandWidth = 0.18;      % the bandwidth of the Gaussian core of meanshift cluster   0.15~0.20

myopt.SLIC_spatial_proximity_weight = 10;  % SLIC superpixel parameter
myopt.SLIC_sp_num = 300;                   % SLIC superpixel parameter: superpixel number

myopt.negative_penalty_ratio = 3.0;  % decreasing negative influences from background superpixels  1.0~3.0

myopt.sigma_c = 7.60;
myopt.sigma_s = 7.00;
        
%% update parameters
myopt.update_incre_num = 15;   % H, cumulated sample number.
myopt.update_freqency = 10;    % W, update frame interval.     
myopt.update_spacing = 1;     % U, sample interval.
myopt.occlusion_rate = .515;  % theta_o, Occlusion Threshold

sp_pos_cluster = [];
sp_neg_cluster = [];
sp_mid_cluster = [];

%% individual parameters
switch (title)
     case 'd16';       p = [647,116.5,19,38,0.00];
        opt = struct('numsample',600, 'affsig',[8, 8, .0, .0, .0, .0]);
        
    case 'skating1';         p = [180,220,35,100,0.0];
       opt = struct('numsample',600, 'affsig',[8,5,.002,.0001,.002,.000]);
       
    case 'board';         p = [155,244,195,153,0.0];
       opt = struct('numsample',600, 'affsig',[15,8,.005,.0001,.005,.000]);      
        
    case 'box';         p = [519,199,86,112,0.0];
       opt = struct('numsample',600, 'affsig',[7,8,.02,.0001,.005,.000]);      
        
    case 'race';         p = [403,150,56,30,0.0];
       opt = struct('numsample',600, 'affsig',[10,10,.005,.001,.006,.000]);      

    case 'surfing1';         p = [218,238,58,110,0.0];
       opt = struct('numsample',600, 'affsig',[16,13,.009,.001,.007,.000]); 
       myopt.update_freqency = 5;

    case 'basketball';         p = [212,262,33,80,0.0];
       opt = struct('numsample',600, 'affsig',[4,4,.000,.000,.000,.0000]);   

    case 'bolt';         p = [350,195,25,60,0.0];
       opt = struct('numsample',600, 'affsig',[5,5,.001,.001,.001,.000]);               

    case 'woman';       p = [219, 156, 30, 92,0.00];
        opt = struct('numsample',600,'affsig',[4,4,.0000,.00,.00,.00]); 

    case 'lemming';   p = [72,252,60,112, 0.00];
        opt = struct('numsample',600, 'affsig',[10,10,.004,.00,.01,.00]);
        myopt.update_freqency = 10;

    case 'singer1';  p = [50, 110 ,55 ,160, 0];
        opt = struct('numsample',600, 'affsig',[2,2,.002,.0005,.0005,.001]);

    case 'girl_mov'; p = [316, 217 ,38 ,150, 0.00];
                opt = struct('numsample',600,'affsig',[10,5, 0.0003, 0.00, 0.0003, .00]);
  
    case 'bird1'; p = [468,110,30,36,0.00];
                 opt = struct('numsample',600, 'affsig',[7,7, 0.00, 0.00, 0.0, .00]);
                 myopt.update_incre_num = 25;

    case 'bird2'; p = [115,252,68,72,0.00];
                 opt = struct('numsample',600, 'affsig',[8 ,8, 0.00, 0.00, 0.0, .00]);

    case 'liquor'; p = [ 292, 255, 68, 202, 0.00];
                 opt = struct('numsample',600, 'affsig',[15 ,15, 0.00, 0.00, 0.0, .00]);

    case 'transformer2_BMP'; p = [ 258, 146, 111, 180, 0.00];
                 opt = struct('numsample',600, 'affsig',[8 ,8, 0.05, 0.0, 0.05, .00]);
 
    otherwise;  error(['unknown title ' title]);
end

%% path of the sequences, you can change it to the directory that contains the sequences 
dataPath = ['data\' title '\'];

%% affine parameter
opt.tmplsize = [myopt.grid_size myopt.grid_size];
param0 = [p(1), p(2), p(3)/opt.tmplsize(2), p(5), p(4)/p(3), 0];
param0 = affparam2mat(param0);

%% get frame number and resolution
files = dir(dataPath);
if ~isdir([dataPath 'results\'])
    LoopNum = length(files) - 2;
else
    LoopNum = length(files) - 3;
end

%% create directory to save results
opt.dump = dump_frames;
if ~isdir([dataPath 'results\'])
    mkdir([dataPath 'results\']);
end
fprintf('%s video is loaded...\n',title);
