%% An RBC model with asset price, irreversibility, and endogenous labor supply with infinite Frisch elasticity
% 2023.09.25
% Hanbaek Lee (hanbaeklee1@gmail.com)
% When you use the code, please cite the paper 
% "A Dynamically Consistent Global Nonlinear Solution 
% Method in the Sequence Space and Applications."
%=========================    
% this file is to check the monotonicity of value/policy function's
% along with the endogenous state in equilibrium.
%=========================    
%=========================    
% housekeeping
%=========================
% clc;
% clear variables;
% close all; 
% fnPath = './functions';
% addpath(fnPath);

%=========================
%load ss
%=========================
ss = load('../solutions/rbcassetirrendolaborinftyfrisch_ss.mat');
globalSol = load('../solutions/rbcassetirrendolaborinftyfrisch_bc.mat');
load('../solutions/rbcassetirrendolaborinftyfrisch_bc.mat');

%=========================
%backward solution
%=========================
iA = tsimpath;
vA  = vgridA(iA);
vw  = 1./tc;
vr  = (1-pgamma)*(pgamma./tw).^(pgamma/(1-pgamma)).*vA.^(1/(1-pgamma))...
      .* (palpha/(1-pgamma)).*tk.^(palpha/(1-pgamma)-1) ...
      + (1-pdelta).*(1-tlambda);
RHS = (1./tc).*(vr);

%%

vKsample = tk(burnin+1:pathlength-burnin);
RHSsample = RHS(burnin+1:pathlength-burnin);
vsimpathSample = tsimpath(burnin+1:pathlength-burnin);

for iAlocation = 1:pnumgridA
tempK = vKsample(vsimpathSample==iAlocation);
tempRHS = RHSsample(vsimpathSample==iAlocation);
subplot(2,4,iAlocation);
scatter(tempK,tempRHS);
xlabel("K","FontSize",15);
ylabel("RHS of Euler","FontSize",15);
temptitle = append('A',num2str(iAlocation));
title(temptitle);
end
set(gcf, 'PaperPosition', [0 0 18 10]); %Position plot at left hand corner with width a and height b.
set(gcf, 'PaperSize', [18 10]); %Set the paper to have width a and height b.Grid off;
location = ['../figures/monotonicity.pdf'];
saveas(gcf, location);
