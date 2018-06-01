function [test, param] = do_tracking(param, tmpl, test, f, train_sum_hist, opt, myopt)
%% Copyright (C) Shu Wang and Fan Yang.
%% All rights reserved.

%% prepare the superpixel
grid_ratio          = myopt.grid_ratio;
ch_bins_num         = myopt.ch_bins_num;
image_size          = myopt.image_size; 
clust_Cent          = test.clust_Cent;
TrainCluster_Weight = test.TrainCluster_Weight;
data2cluster        = test.data2cluster;

% determine the size of the warpped image according to the bouding box
% of the previous frame.
temp_length = uint16(norm([test.p(3)/2,test.p(4)/2])*grid_ratio);

test.last_box = zeros(1,4);
test.last_box(1) = max(1,test.p(1) - temp_length);
test.last_box(2) = max(1,test.p(2) - temp_length);
test.last_box(3) = min(image_size.cx , test.p(1) + temp_length);
test.last_box(4) = min(image_size.cy , test.p(2) + temp_length);
test.warpimg =  test.image(test.last_box(2) : test.last_box(4),...
                           test.last_box(1) : test.last_box(3), :);
test.warpimg_hsi = rgb2hsi(test.warpimg);                        
warpimg_size = size(test.warpimg);
test.warpimg_tmpl.cx = warpimg_size(2);
test.warpimg_tmpl.cy = warpimg_size(1);

%% SLIC segmentation
test.labels = SLIC_mex(test.warpimg, myopt.SLIC_sp_num, myopt.SLIC_spatial_proximity_weight);

N_superpixels = unique(test.labels);
% N_superpixels = union(test.labels(:), test.labels(1));
N_superpixels = N_superpixels(:);
test.sp_num = max(N_superpixels);       % record the number of superpixels of this frame
[sp_pixel_num, ~, temp_sp_cl_hist] = t1_cal_hsi_hist(test, f, ch_bins_num, N_superpixels);

cluster_dis = slmetric_pw(temp_sp_cl_hist, train_sum_hist, 'sqdist');

[~, temp_index] = min(cluster_dis, [], 2);
[max_dist, ~] = max(cluster_dis, [] ,2);

w1 = zeros(test.sp_num, 1);    
    
for i = 1:test.sp_num
    Cent = data2cluster(temp_index(i));  % the cluster center each super pixel is heading at 
    dist = exp(-2*norm((temp_sp_cl_hist(:,i) - clust_Cent(:,Cent))/max_dist(i)));   % the exp(-distance) of every super pixel to its cluster center. the closer ,  the larger        
    w1(i) = dist * TrainCluster_Weight(Cent,1);    % the w1 of every superpixel, the larger, the more likely to be the object
end

temp_labels = test.labels;
% pro_image_w1 = zeros(test.warpimg_tmpl.cy,test.warpimg_tmpl.cx);
pro_image_w1 = reshape(w1(temp_labels(:)), test.warpimg_tmpl.cy,test.warpimg_tmpl.cx);
% for i=1:test.warpimg_tmpl.cy   
%     for j=1:test.warpimg_tmpl.cx 
%         pro_image_w1(i,j) = w1(temp_labels(i,j));
%     end
% end

test.pro_image_w1 = -1*ones(image_size.cy,image_size.cx);
test.pro_image_w1(test.last_box(2) : test.last_box(4),...
                  test.last_box(1) : test.last_box(3), :)...
                  = pro_image_w1;

%% particle sampling
n = opt.numsample;
sz = size(tmpl.mean);
param.save_est = param.est;

if ~isfield(test,'param')
    test.init_length = temp_length;
end

if ~isfield(param,'param')
    param.param = repmat(affparam2geom(param.est(:)), [1,n]);
else
    param.param = repmat(affparam2geom(param.est(:)), [1,n]);
end
param.param = param.param + randn(6,n).*repmat(opt.affsig(:),[1,n]);  


%% do tracking
% find severial good candidates according to the probobility map
test.tmplsz = [test.warp_p(4),test.warp_p(3)]; % block size
test.tmplsz = double(uint16(test.tmplsz));  
N = test.tmplsz(1) * test.tmplsz (2);
test.param = param.param;

for i = 1:size(param.param,2)
    temp_param = affparam2geom(affparam2mat(param.param(:,i)));
    temp_pp = [temp_param(1),temp_param(2),temp_param(3)*sz(2),temp_param(5)*temp_param(3)*sz(1),temp_param(4)];
    test.param(:,i) = [temp_pp(1), temp_pp(2), temp_pp(3)/test.tmplsz(2), temp_pp(5), temp_pp(4)/temp_pp(3)*test.tmplsz(2)/test.tmplsz(1), 0];
end

% get the size of every test.param's bounding box
test.p_param = [test.param(1,:); test.param(2,:); test.param(3,:)* test.tmplsz(2); (test.param(5,:)) .* (test.param(3,:)) * test.tmplsz(1); test.param(4,:)];
test.rect_size = (test.p_param(3,:)) .* (test.p_param(4,:)); % 1*n matrix , representing the size of the sample rectangle
% get the motion probability of every test.param's rectangle
test.motion_pro_v1 = t1_cal_gaussian_pro(test.p_param(1:2,:),test.p(1:2)', myopt.mot_sig_v1);
test.motion_pro_v2 = t1_cal_gaussian_pro(test.p_param(3:4,:),test.p(3:4)', myopt.mot_sig_v2);

wimgs_w1 = warpimg(test.pro_image_w1, affparam2mat(test.param), test.tmplsz); 

temp_wimgs_w1 = reshape(wimgs_w1,[N,n]);
[test.spt_conf, test.spt_conf_idx] = max(sum(temp_wimgs_w1));

warp_tmpl_size = test.tmplsz(1)*test.tmplsz(2);
motion_pro_v1_max = max(test.motion_pro_v1);
motion_pro_v2_max = max(test.motion_pro_v2);

test.conf = sum(temp_wimgs_w1);

for i = 1:n
    if test.conf(i) > 0
        test.conf(i) = test.conf(i) * (test.rect_size(i)) / warp_tmpl_size;
    else
        test.conf(i) = test.conf(i) / (test.rect_size(i)) * warp_tmpl_size;
    end
end

if min(test.conf) < 0
    test.conf = test.conf + abs(min(test.conf));
    test.conf = test.conf / max(test.conf);
else
    test.conf = test.conf - min(test.conf);
    test.conf = test.conf / max(test.conf);
end

[~, spt_maxidx] = max(test.conf);
if f == myopt.train_frame_num + 1
    test.save_prob = test.spt_conf;
    test.save_std = test.save_prob * 0.5;
    test.incre_prob = 0;
    test.ivt_error = 0;
    test.update_spt_conf = ones(1,myopt.train_frame_num ) * test.spt_conf;
end

test.est = affparam2mat(test.param(:,spt_maxidx));
test.p = affparam2original(test.est, test.tmplsz);

%% normalize confidence 
test.combine_conf = test.conf';
test.combine_conf = test.combine_conf  .* test.motion_pro_v1' .* test.motion_pro_v2' / motion_pro_v1_max / motion_pro_v2_max;

% % uncomment this part to save confidence map for each frame
% if f == myopt.train_frame_num + 1
%     figure('position',[100 100 test.warpimg_tmpl.cx test.warpimg_tmpl.cy]); clf;   
%     set(gcf,'DoubleBuffer','on','MenuBar','none');
%     axes('position', [0.00 0 1.00 1.0]);
% else
%     figure(2);
% end
% imagesc(pro_image_w1);
% imwrite(frame2im(getframe(gcf)), [myopt.dataPath 'results\conf_' t1_num2fiveD(f,4) '.png']);

% % uncomment this part to save segmentation results
% level = graythresh(pro_image_w1);
% BW = im2bw(pro_image_w1, level);
% Seg_img = double(test.warpimg);
% Seg_img(:,:,1) = Seg_img(:,:,1) .* BW ;
% Seg_img(:,:,2) = Seg_img(:,:,2) .* BW ;
% Seg_img(:,:,3) = Seg_img(:,:,3) .* BW ;
% Seg_img = uint8(Seg_img);
% 
% if f == myopt.train_frame_num + 1
%     figure('position',[(130+size(Seg_img,2)) 100 test.warpimg_tmpl.cx test.warpimg_tmpl.cy]); clf;   
%     set(gcf,'DoubleBuffer','on','MenuBar','none');
%     axes('position', [0.00 0 1.00 1.0]);
% else
%     figure(3);
% end
% imshow(Seg_img);
% imwrite(frame2im(getframe(gcf)), [myopt.dataPath 'results\seg_' t1_num2fiveD(f,4) '.png']);

%% collect information to update appearance model
area_size = warpimg_size(1) * warpimg_size(2);
test.Occlusion_conf = 0.5 - test.spt_conf / area_size;
if test.Occlusion_conf > myopt.occlusion_rate
    test.update_flag =0;
    test.temp_sp_cl_hist = temp_sp_cl_hist;
    test.sp_pixel_num = sp_pixel_num;
else
    test.update_flag =1;
    [~, combine_maxidx] = max(test.combine_conf);
    test.combine_est = affparam2mat(test.param(:,combine_maxidx));
    test.combine_p = affparam2original(test.combine_est, test.tmplsz);
    test.p = test.combine_p;
    test.est = test.combine_est;
    param.p = test.combine_p;
    param.est = affparam2ultimate( param.p,sz);

    test.temp_sp_cl_hist = temp_sp_cl_hist;
    test.sp_pixel_num = sp_pixel_num;
    test.warp_p = test.combine_p;

    test.warp_p(1) = test.combine_p(1) - test.last_box(1);
    test.warp_p(2) = test.combine_p(2) - test.last_box(2);
end