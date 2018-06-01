%% compile necessary functions
if do_compile
    cd ./affine
    mex -O interp_fast.cpp
    cd ..
    cd ./SLIC
    mex -O SLIC_mex.cpp SLIC.cpp
    cd ..
    cd ./pwmetric
    mex -O pwhamming_cimp.cpp
    mex -O pwmetrics_cimp.cpp
    cd ..
end