function param = do_simple_track(frm, tmpl, param, opt)
% Do template simple tracking
% Adapted from the code by D. Ross et al.

n = opt.numsample;
sz = size(tmpl.mean);
N = sz(1)*sz(2);

if ~isfield(param,'param')
    param.param = repmat(affparam2geom(param.est(:)), [1,n]);
else
    cumconf = cumsum(param.conf);
    idx = floor(sum(repmat(rand(1,n),[n,1]) > repmat(cumconf,[1,n])))+1;
    param.param = param.param(:,idx);
end

param.param = param.param + randn(6,n).*repmat(opt.affsig(:),[1,n]);  % sample
wimgs = warpimg(frm, affparam2mat(param.param), sz);                  % sample candidates
diff = repmat(tmpl.mean(:),[1,n]) - reshape(wimgs,[N,n]);

param.conf = exp(-sum(diff.^2)./opt.condenssig)';
param.conf = param.conf ./ sum(param.conf);
[~, maxidx] = max(param.conf);
param.est = affparam2mat(param.param(:,maxidx));
param.p = affparam2original(param.est,sz);
param.wimg = wimgs(:,:,maxidx);