function drawopt = drawtrackresult(drawopt, fno, image_size, frame, tmpl, param, pts, flag)
%% Copyright (C) Shu Wang.
%% All rights reserved.

if isempty(drawopt)  
    figure('position',[50 100 image_size.cx image_size.cy]); clf;                        
    set(gcf,'DoubleBuffer','on','MenuBar','none');
    drawopt.curaxis = [];
    drawopt.curaxis.frm  = axes('position', [0.00 0 1.00 1.0]);
end

curaxis = drawopt.curaxis;
axes(curaxis.frm);      
imagesc(frame, [0,1]); 
hold on;     

sz = size(tmpl.mean);
if  nargin == 8
    sz = param.tmplsz;
    sz = [sz(2) sz(1)];
    if exist('param.combine_est')
        param.est =  param.combine_est;
    end
end
p = drawbox(sz, param.est, 'Color','y', 'LineWidth',4);
text(5, 20, ['#  ' num2str(fno)], 'Color','y', 'FontSize',24);
axis equal off;
hold off;
drawnow;

