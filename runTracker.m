%% An implementation of the superpixel-based tracking method proposed by 
%%    Shu Wang, Huchuan Lu, Fan Yang, Ming-Hsuan Yang, Superpixel Tracking,
%%    ICCV2011, pp. 1323-1330, 2011.
%% Copyright (C) Shu Wang and Fan Yang
%% All rights reserved.

close all;
clear; clc;
addpath('affine', 'meanshift', 'scripts', 'SLIC', 'pwmetric');
trackparam;		%% parameter settings
compile;        %% do compile or not
rand(0); randn(0);

img_num = 4;
%% get video information
if exist([dataPath t1_filename(1,img_num) '.jpg'],'file')
    iframe = imread([dataPath t1_filename(1,img_num) '.jpg']);
elseif exist([dataPath t1_filename(1,img_num) '.png'],'file')
    iframe = imread([dataPath t1_filename(1,img_num) '.png']);
else
    iframe = imread([dataPath t1_filename(1,img_num) '.bmp']);
end

if size(iframe, 3) == 3
    temp_frame = double(rgb2gray(iframe))/256;
else
    temp_frame = double(iframe)/256;
end
save_param4txt = zeros(LoopNum,4);
save_matrix4txt(1,:) = uint16(p(1:4));
myopt.dataPath = dataPath;

%% image size and intermediate variable of motion model
myopt.image_size.cx = size(iframe,2);
myopt.image_size.cy = size(iframe,1);
lambda_r = (size(iframe,2) + size(iframe,1))/2;
myopt.mot_sig_v1 = myopt.sigma_c * lambda_r;
myopt.mot_sig_v2 = myopt.sigma_s * lambda_r;

%% simple track parameter. Do not modify.
if ~exist('opt','var')        opt = [];  end
if ~isfield(opt,'tmplsize')   opt.tmplsize = [32,32];  end                 
if ~isfield(opt,'numsample')  opt.numsample = 400;  end 
if ~isfield(opt,'affsig')     opt.affsig = [4,4,.02,.02,.005,.001];  end    
if ~isfield(opt,'condenssig') opt.condenssig = 0.25;  end                 

if ~isfield(opt,'maxbasis')   opt.maxbasis = 16;  end                   
if ~isfield(opt,'batchsize')  opt.batchsize = 5;  end                      
if ~isfield(opt,'errfunc')    opt.errfunc = 'L2';  end                     
if ~isfield(opt,'ff')         opt.ff = 1.0;  end                           
if ~isfield(opt,'minopt')
  opt.minopt = optimset; opt.minopt.MaxIter = 25; opt.minopt.Display='off';
end

%% parameter setting for simple track 
if size(iframe, 3) == 1
    newf = zeros(size(iframe,1), size(iframe,2), 3);
    newf(:,:,1) = iframe;
    newf(:,:,2) = iframe;
    newf(:,:,3) = iframe;
    iframe = uint8(newf);
end
temp_hsi_image = rgb2hsi(iframe);
tmpl.mean_Hue = temp_hsi_image(:,:,1);
tmpl.mean_Sat = temp_hsi_image(:,:,2);
tmpl.mean_Inten = temp_hsi_image(:,:,3);
tmpl.mean = warpimg(temp_frame, param0, opt.tmplsize);
tmpl.basis = [];                                    
tmpl.eigval = [];                                 
tmpl.numsample = 0;                            
tmpl.reseig = 0;                         
sz = size(tmpl.mean);  
N = sz(1)*sz(2);                                        

param = [];
param.est = param0;                                    
param.wimg = tmpl.mean;     

%% superpixel tracking train parameters
opt.dump = dump_frames;  % save results or not
train_box_param = zeros(6,myopt.train_frame_num);  % initial training bounding box
train_box_param(:,1) = param0;

%% draw initial track window    
pts = [];
drawopt = drawtrackresult([], 1, myopt.image_size, iframe, tmpl, param, pts);
drawopt.showcondens = 0;  drawopt.thcondens = 1/opt.numsample;

%% track the sequence from 2nd frame
for f = 2:myopt.train_frame_num
    if exist([dataPath t1_filename(f,img_num) '.jpg'],'file')
        iframe = imread([dataPath t1_filename(f,img_num) '.jpg']);
    elseif exist([dataPath t1_filename(f,img_num) '.png'],'file')
        iframe = imread([dataPath t1_filename(f,img_num) '.png']);
    else
        iframe = imread([dataPath t1_filename(f,img_num) '.bmp']);
    end
    
    if size(iframe, 3) == 3
        frame_image = double(rgb2gray(iframe))/256;
    else
        frame_image = double(iframe)/256;
    end
  
    if size(iframe, 3) == 1
        newf = zeros(size(iframe,1), size(iframe,2), 3);
        newf(:,:,1) = iframe;
        newf(:,:,2) = iframe;
        newf(:,:,3) = iframe;
        iframe = uint8(newf);
    end

    % do simple tracking
    param = do_simple_track(frame_image, tmpl, param, opt);
    train_box_param(:,f) = param.est;
    
    % draw result
    drawopt = drawtrackresult(drawopt, f, myopt.image_size, iframe, tmpl, param, pts);
    if (isfield(opt,'dump') && opt.dump > 0)
        imwrite(frame2im(getframe(gcf)),[dataPath 'results\' t1_filename(f,4) '.png']);
    end
    save_matrix4txt(f,:) = uint16(param.p(1:4));
end

%% training process
for f = 1:myopt.train_frame_num
    if exist([dataPath t1_filename(f,img_num) '.jpg'],'file')
        frame(f).image = imread([dataPath t1_filename(f,img_num) '.jpg']);
    elseif exist([dataPath t1_filename(f,img_num) '.png'],'file')
        frame(f).image = imread([dataPath t1_filename(f,img_num) '.png']);
    else
        frame(f).image = imread([dataPath t1_filename(f,img_num) '.bmp']);
    end
    temp_image = double(frame(f).image)/256;
   
    if size(frame(f).image, 3) == 1
        newf = zeros(size(frame(f).image,1), size(frame(f).image,2), 3);
        newf(:,:,1) = frame(f).image;
        newf(:,:,2) = frame(f).image;
        newf(:,:,3) = frame(f).image;
        frame(f).image = uint8(newf);
    end
    
    % accumulate information to build the appearance model
    [frame, train_sp_sum_num, sp_index_pre, train_sum_hist_index, train_sum_hist] ...
    = t1_train_info(opt, myopt, f, train_box_param, frame, train_sp_sum_num, ...
                    sp_index_pre, train_sum_hist_index, train_sum_hist);

    % show results
    % drawopt = drawtrackresult(drawopt, f, myopt.image_size, frame(f).I_s, tmpl, frame(f).warp_param, pts);  
    fprintf('\nNow the %d frame is segmented over...\n',f);
    fprintf('%d frames histogram is calculated\n',f); 
    
    % Construct the appearance model
    if f == myopt.train_frame_num
        fprintf('\n training cluster step:\n all %d training frames histogram is collected,\n waiting for Mean Shift Clustering...\n',f); 
        test = t1_construct_appearance_model(train_sum_hist, myopt,frame, train_sp_sum_num, sp_index_pre, f);
        
        %% parameters transfered for the testing frames:
        updata_num = f;
        for k = 1:f
            update(k).labels = frame(k).labels;       
            update(k).warp_p = frame(k).warp_p;
            update(k).warpimg_tmpl = frame(k).warpimg_tmpl;
        end
        update_hist_sum = train_sum_hist;
        update_sp_num = sp_index_pre(f+1);
        update_index_pre = sp_index_pre;
        update_index_pre(1) = [];
        update_index_pre_final = sp_index_pre;
        clear frame;
    end
end

%% run superpixel tracking 
last_box_param = train_box_param(myopt.train_frame_num, :);
test.update_interval_num = myopt.train_frame_num;
update_negtive = 0;

for f = myopt.train_frame_num+1:LoopNum
    if exist([dataPath t1_filename(f,img_num) '.jpg'],'file')
        test.image = imread([dataPath t1_filename(f,img_num) '.jpg']);
    elseif exist([dataPath t1_filename(f,img_num) '.png'],'file')
        test.image = imread([dataPath t1_filename(f,img_num) '.png']);
    else
        test.image = imread([dataPath t1_filename(f,img_num) '.bmp']);
    end

    if size(test.image, 3) == 1
        newf = zeros(size(test.image,1), size(test.image,2), 3);
        newf(:,:,1) = test.image;
        newf(:,:,2) = test.image;
        newf(:,:,3) = test.image;
        test.image = uint8(newf);
    end
    
    % do tracking
    try
        [test, param] = do_tracking(param, tmpl, test, f, train_sum_hist, opt, myopt);
    catch err
        disp('Tracking failed!');
        break;
    end
    
    % show tracking results
    figure(1);
    drawopt = drawtrackresult(drawopt, f, myopt.image_size, test.image ,tmpl, test, pts, 1);
    
    % save coordinates of bounding box to the text file
    save_matrix4txt(f,:) = uint16(test.p(1:4));
   
    temp_k = test.save_prob - test.spt_conf;
    
    % accumulate information to update the appearance model
    [test, update, updata_num, update_index_pre, update_hist_sum, update_sp_num, update_index_pre_final] ...
     = t1_update_info(myopt, test, update, updata_num, update_index_pre, update_hist_sum, update_sp_num, update_index_pre_final);
    drawnow;
    
    % update the appearance model
    if test.update_interval_num >= myopt.update_freqency && (length(update_index_pre) == myopt.update_incre_num)
        [test, train_sum_hist, updata_num, update_sp_num, update_flag, update_negtive]... 
         = t1_update_app_model(myopt, update, test, update_hist_sum, update_index_pre, update_index_pre_final);
    end
       
    % save images of tracking results
    if (isfield(opt,'dump') && opt.dump > 0)
        imwrite(frame2im(getframe(gcf)), [dataPath 'results\' t1_filename(f,4) '.png']);
    end
    
    % clean the useless data
    clear cluster_dis sp2cluster sp_pos_cluster sp_neg_cluster sp_mid_cluster;
end

% save results
if exist([dataPath 'results\' title '_spt.txt'], 'file')
    delete([dataPath 'results\' title '_spt.txt']);
end
dlmwrite([dataPath 'results\' title '_spt.txt'], save_matrix4txt);
%% EOF