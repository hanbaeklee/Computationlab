%% An RBC model with irreversible investment
% 2023.09.25
% Hanbaek Lee (hanbaeklee1@gmail.com)
% When you use the code, please cite the paper 
% "A Dynamically Consistent Global Nonlinear Solution 
% Method in the Sequence Space and Applications."
%=========================    
% this file is to run the whole codes.
%=========================    
%=========================
% housekeeping
%=========================
clc;
clear variables;
close all;
fnpath = './functions';
addpath(fnpath);

%%
%=========================
% run the codes
%=========================
cd("./maincodes/")

% obtain the steady state
rbcirreversible_ss;

% run the model with aggregate uncertainty
rbcirreversible_bc;

% run the comparison codes across the solutions
rbcirreversible_comp;
rbcirreversible_dyincon_occbinLinear;
rbcirreversible_dyincon_occbin;
rbcirreversible_dyincon_gdsge;

% run the testers
rbcirreversible_ee;
rbcirreversible_monotonicity;

cd("../")