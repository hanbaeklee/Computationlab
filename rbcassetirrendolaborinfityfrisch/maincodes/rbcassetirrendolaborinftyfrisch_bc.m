%% An RBC model with asset price, irreversibility, and endogenous labor supply with infinite Frisch elasticity
% 2023.09.25
% Hanbaek Lee (hanbaeklee1@gmail.com)
% When you use the code, please cite the paper 
% "A Dynamically Consistent Global Nonlinear Solution 
% Method in the Sequence Space and Applications."
%=========================    
% this file is to compute the dsge allocations over a simulated path.
%=========================    
%=========================
% housekeeping
%=========================
clc;
clear variables;
close all;
fnpath = '../functions';
addpath(fnpath);

%=========================
% load the stead-state equilibrium allocations
%=========================
dir = '../solutions/rbcassetirrendolaborinftyfrisch_ss.mat';
load(dir);
ss = load('../solutions/rbcassetirrendolaborinftyfrisch_ss.mat');

%=========================
% aggregate shock
%=========================
% Tauchen method
prho_A = 0.859;
psigma_A = 0.014;

% Tauchen method
pnumgridA = 5;
[mtransA, vgridA] = ...
fnTauchen(prho_A, 0, psigma_A^2, pnumgridA, 2);
vgridA = exp(vgridA);

%=========================
% simulation path
%=========================
seed = 100;
rng(seed);
T = 1001;
% T = 2001;% T = 3001;% T = 5001;% T = 10001;
burnin = 500;
pathlength = T+burnin;
pinitialpoint = 1;
tsimpath = fnSimulator(pinitialpoint,mtransA,burnin+T);    

%=========================    
% initial guess for the allocation path
%=========================
tp      = ss.eq.p*ones(pathlength,1);
tc      = ss.eq.c*ones(pathlength,1);
tl      = ss.eq.l*ones(pathlength,1);
tw      = ss.eq.w*ones(pathlength,1);
tk      = ss.eq.k*ones(pathlength,1) + normrnd(0,0.0000001,pathlength,1);
ty      = ss.eq.y*ones(pathlength,1);
ti      = ss.eq.k*pdelta*ones(pathlength,1);
tr      = ss.eq.r*ones(pathlength,1);
tj      = ss.eq.j*ones(pathlength,1);
tlambda = zeros(pathlength,1);

% separate paths to be updated iteratively
tlambdanew = zeros(pathlength,1);
tknew   = ss.eq.k*ones(pathlength,1);

%=========================    
% resume from the last one
%=========================    
% use the following line if you wish to start from where you stopped
% before.
% load '../solutions/WIP_rbcassetirrendolaborinftyfrisch_bc.mat';

%=========================
% numerical parameters
%=========================
% the updating weights
weightold1   = 0.9500; % updating weight for capital stock 
weightold2   = 0.9950; % updating weight for consumption
weightold3   = 0.9950; % updating weight for lagrange mutiplier
% for an extremely high accuracy, you might consider weight as high as
% 0.9990;
% equilibrium convergence criteria 
tol_ge       = 1e-9;

tic;
%%
%=========================
% repeated transition method
%=========================
% iteration preparation    
pnumiter    = 1;  % this is for interim reports
error2      = 10; % this is for terminal condition

% vectorize the shock-related paths
iA = tsimpath;
ifuture = [(2:pathlength)';pathlength];
futureShock = tsimpath(ifuture);
vA  = vgridA(iA);

% prior calculation of time-series of the transition probabilities to the realized
% aggregate shocks on the simulated path
mTransRealized = zeros(size(tk));
for iTrans = 1:length(tk)
mTransRealized(iTrans,1) = mtransA(iA(iTrans),futureShock(iTrans));
end

while error2>tol_ge
    
%=========================
% step 1: backward solution
%=========================
% even if it's the bacward-solution step, it does not include the backward
% loop, as the step is vectorized.

% calculate the future endogenous capital allocations based on the time
% series of endogenous capital in the (n-1)th iteration.
tkprime = [tk(2:end);tk(1)];
tw      = peta.*tc;

% declare an empty object tempV1 that will carry the cumulatively summed expected
% values.
tempV1 = 0;
tempV2 = 0;
tempV3 = 0;
for iAprime = 1:pnumgridA

    Aprime = vgridA(iAprime);

    % find a period where the future shock realization is the same as
    % iAprime and the capital stock is closest to vKprime from below and above.
    candidate = tk(find(tsimpath==iAprime)); % iso-shock periods
    candidateLocation = find(tsimpath==iAprime); % iso-shock period locations
    candidate(candidateLocation>pathlength-burnin) = []; % last burnin periods cannot be a candidate
    candidate(candidateLocation<burnin) = [];  % initial burnin periods cannot be a candidate
    candidateLocation(candidateLocation>pathlength-burnin) = []; % last burnin periods cannot be a candidate
    candidateLocation(candidateLocation<burnin) = [];  % initial burnin periods cannot be a candidate
    [candidate,index] = sort(candidate); % to find the closest, sort the candidates in order
    candidateLocation = candidateLocation(index); % save the location

    klow = sum(repmat(candidate',length(tkprime),1)<tkprime,2); % using the sorted vector, find the period where the capital stock is closest to vKprime from below
    klow(klow<=1) = 1; % the location cannot go below 1.
    klow(klow>=length(index)) = length(index)-1; % the location cannot go over the length(index)-1: note that it's the closest from BELOW.
    khigh = klow+1; %define the period where the capital stock is closest to vKprime from above
    weightlow = (candidate(khigh) - tkprime)./(candidate(khigh)-candidate(klow)); %compute the weight on the lower side
    weightlow(weightlow<0) = 0; % optional restriction on the extrapolation
    weightlow(weightlow>1) = 1; % optional restriction on the extrapolation
   
    lambdaprime = weightlow.*tlambda(candidateLocation(klow )) + (1-weightlow).*tlambda(candidateLocation(khigh ));    
    wprime = weightlow.*tw(candidateLocation(klow )) + (1-weightlow).*tw(candidateLocation(khigh));
    rprime = weightlow.*tr(candidateLocation(klow )) + (1-weightlow).*tr(candidateLocation(khigh));

    tempV1 = tempV1 + (futureShock ~= iAprime).* pbeta.*...
                mtransA(iA,iAprime).*...
                (weightlow.*(1./tc(candidateLocation(klow ))).*(rprime) ...
           + (1-weightlow).*(1./tc(candidateLocation(khigh))).*(rprime) );

    tempV2 = tempV2 + (futureShock ~= iAprime).* pbeta.*...
                mtransA(iA,iAprime).*...
                (weightlow.*(tc./tc(candidateLocation(klow ))).*(rprime ) ...
           + (1-weightlow).*(tc./tc(candidateLocation(khigh))).*(rprime) );

    tempV3 = tempV3 + (futureShock ~= iAprime).* pbeta.*...
                mtransA(iA,iAprime).*...
                (weightlow.*(tc./tc(candidateLocation(klow ))).*(tj(candidateLocation(klow ))) ...
           + (1-weightlow).*(tc./tc(candidateLocation(khigh))).*(tj(candidateLocation(khigh))) );    

end

% for the realized future shock level on the simulated path
wfuture    = tw(ifuture);
rfuture    = tr(ifuture);
tempV1     = tempV1 + pbeta*...
                mTransRealized.*(1./tc(ifuture)).*(rfuture); 
tempV2     = tempV2 + pbeta*...
                mTransRealized.*(tc./tc(ifuture)).*(rfuture); 
tempV3     = tempV3 + pbeta*...
                mTransRealized.*(tc./tc(ifuture)).*(tj(ifuture)); 

% update the allocations
tempC      = ((1-tlambda)./tempV1);
tr         = (1-pgamma)*(pgamma./tw).^(pgamma/(1-pgamma)).*vA.^(1/(1-pgamma))...
           .* (palpha/(1-pgamma)).*tk.^(palpha/(1-pgamma)-1) ...
           + (1-pdelta).*(1-tlambda);
tl         = (pgamma.*vA.*tk.^palpha./tw).^(1/(1-pgamma));
ty         = vA.*tk.^(palpha).*tl.^(pgamma);
ti         = ty - tempC;
vjnew      = (1-pgamma)*vA.*tk.^(palpha).*tl.^(pgamma) - ti + tempV3;
tlambdanew = 1 - tempV2;

%irreversibility
tlambdanew(ti>pphi*ss.eq.i) = 0;
ti(ti<=pphi*ss.eq.i) = pphi*ss.eq.i;

%=========================    
% step 2: simulate forward
%=========================   
vkpast = [ss.eq.k;tk(1:end-1)];
vipast = [ss.eq.k*pdelta;ti(1:end-1)];

tknew = (1-pdelta)*vkpast + vipast;
tcnew = vA.*tknew.^(palpha).*tl.^(pgamma) - ti;
error2 = mean(([...
    tc      - tcnew;...
    tk      - tknew;...
    tlambda - tlambdanew...
    ]).^2);
errorK = tk - tknew;

tc      = weightold1*tc        + (1-weightold1)*tcnew;
tk      = weightold2*tk        + (1-weightold2)*tknew;
tlambda = weightold3*tlambda   + (1-weightold3)*tlambdanew;
tkprime = [tk(2:end);tk(1)];
tj      = vjnew;

if (floor((pnumiter-1)/500) == (pnumiter-1)/500)
%=========================  
% Report
%========================= 
Phrase = ['Iteration is in progress: ',num2str(pnumiter),'st iteration'];
disp(Phrase);
fprintf(' \n');
fprintf('Convergence criterion: \n');
fprintf('Error: %.18f \n', error2);
fprintf(' \n');
    
subplot(1,2,1);
plot(1:pathlength,tk(1:pathlength));hold on;
plot(1:pathlength,tknew(1:pathlength),'-.');
xlim([1,pathlength]);
hold off;
legend("Predicted K","Realized K","location","northeast");

subplot(1,2,2);
plot(1:pathlength,tc(1:pathlength));hold on;
plot(1:pathlength,tcnew(1:pathlength),'-.');
xlim([1,pathlength]);
hold off;
legend("Predicted C","Realized C","location","northeast");

pause(0.2);

%=========================  
% save (mid)
%=========================  
save '../solutions/WIP_rbcassetirrendolaborinftyfrisch_bc.mat';
toc;

end

pnumiter = pnumiter+1;

end % end of the final loop

%=========================  
% save (final)
%=========================  
save '../solutions/rbcassetirrendolaborinftyfrisch_bc.mat';

%%
%=========================  
% final report
%========================= 
fprintf('\n');
fprintf('======================== \n');
fprintf('Final report\n');
fprintf('======================== \n');
fprintf('Convergence criterion: \n');
fprintf('Error: %.9f \n', error2);

fprintf('\n');
fprintf('======================== \n');
fprintf('Business cycle statistics for the raw time series\n');
fprintf('======================== \n');
fprintf('mean log(output): %.4f \n', mean(log(ty)));
fprintf('st. dev. log(output): %.4f \n', std(log(ty)));
fprintf('skewness log(output): %.4f \n', skewness(log(ty)));
fprintf('------------------------ \n');
fprintf('mean log(investment): %.4f \n', mean(log(ti)));
fprintf('st. dev. log(investment): %.4f \n', std(log(ti)));
fprintf('skewness log(investment): %.4f \n', skewness(log(ti)));
fprintf('------------------------ \n');
fprintf('mean log(consumption): %.4f \n', mean(log(tc)));
fprintf('st. dev. log(consumption): %.4f \n', std(log(tc)));
fprintf('skewness log(consumption): %.4f \n', skewness(log(tc)));

fprintf('\n');
fprintf('======================== \n');
fprintf('Business cycle statistics for the HP-filtered time series\n');
fprintf('======================== \n');
[~,vYhpfilter] = hpfilter(log(ty),1600);
[~,vIhpfilter] = hpfilter(log(ti),1600);
[~,vChpfilter] = hpfilter(log(tc),1600);
fprintf('mean log(output): %.4f \n', mean(log(vYhpfilter)));
fprintf('st. dev. log(output): %.4f \n', std(log(vYhpfilter)));
fprintf('skewness log(output): %.4f \n', skewness(log(vYhpfilter)));
fprintf('------------------------ \n');
fprintf('mean log(investment): %.4f \n', mean(log(vIhpfilter)));
fprintf('st. dev. log(investment): %.4f \n', std(log(vIhpfilter)));
fprintf('skewness log(investment): %.4f \n', skewness(log(vIhpfilter)));
fprintf('------------------------ \n');
fprintf('mean log(consumption): %.4f \n', mean(log(vChpfilter)));
fprintf('st. dev. log(consumption): %.4f \n', std(log(vChpfilter)));
fprintf('skewness log(consumption): %.4f \n', skewness(log(vChpfilter)));

%%
%=========================  
% dynamic consistency report
%========================= 
fprintf('\n');
fprintf('======================== \n');
fprintf('dynamic consistency report for rtm \n');
fprintf('======================== \n');
disp(['max absolute error (in pct. of steady-state K): ', num2str(100*max(abs(errorK))/ss.eq.k),'%']);
disp(['root mean sqaured error (in pct. of steady-state K): ', num2str(100*sqrt(mean(errorK.^2))/ss.eq.k),'%']);
fprintf('\n');
figure;
hist(100*errorK/ss.eq.k,100);
xlim([-1,1]);
xlabel("Dynamic consistency error (in pct. of steady-state K)")
location = ['../figures/err_hist.pdf'];
saveas(gcf, location);

%%
%=========================  
% fitting LoM into the linear specification 
%========================= 
endoState = tk(burnin+1:end-1);
exoState = vgridA(tsimpath(burnin+1:end-1));
endoStatePrime = tk(burnin+2:end);
intercept = ones(size(endoState));

% independent variable
x = [intercept ...
    ,log(endoState) ...
    ,log(exoState) ...
    ,log(endoState).*log(exoState)...
    ];

% dependent variable
y = log(endoStatePrime);

[coeff,bint1,r1,rint1,R1] = regress(y,x);
fprintf('======================== \n');
fprintf('Fitting the true LoM into the log-linear specification\n');
fprintf('======================== \n');
disp(['R-squared: ',num2str(R1(1))]);
fprintf(' \n');
fitlm(x,y,'Intercept',false)

% recover the implied dynamics
startingPoint = burnin+1;
startingEndo = endoState(1);
recovered = ones(1,pathlength - burnin)*startingEndo;
for iTrans = 1:(pathlength - burnin-1)
% endoStateTemp = endoState(iTrans);
endoStateTemp = recovered(iTrans);
exoStateTemp = exoState(iTrans);
tempX = [1 ...
    ,log(endoStateTemp)...
    ,log(exoStateTemp)...
    ,log(endoStateTemp)*log(exoStateTemp)...
    ];
tempVal = coeff'*tempX';
recovered(iTrans+1) = exp(tempVal);
end

samplePeriod = 500:1000;
figure;
plot(samplePeriod,endoState(samplePeriod),'Color','red','LineWidth',1.5);hold on;
plot(samplePeriod,recovered(samplePeriod),'Color','blue','LineStyle','--','LineWidth',1.5);
legend("True LoM","Linear LoM","location","best","FontSize",15)
location = ['../figures/lom.pdf'];
saveas(gcf, location);


%%
%=========================  
% fitting wage dynamics into the linear specification 
%========================= 
endostate = tk(burnin+1:end-1);
exostate = vgridA(tsimpath(burnin+1:end-1));
endoprice = tw(burnin+1:end-1);
intercept = ones(size(endostate));

% independent variable
x = [intercept ...
    ,log(endostate) ...
    ,log(exostate) ...
    ,log(endostate).*log(exostate)...
    ];

% dependent variable
y = log(endoprice);

[coeff,bint1,r1,rint1,R1] = regress(y,x);
fprintf('======================== \n');
fprintf('Fitting the true LoM into the log-linear specification\n');
fprintf('======================== \n');
disp(['R-squared: ',num2str(R1(1))]);
fprintf(' \n');
fitlm(x,y,'Intercept',false)

% recover the implied dynamics
recovered = zeros(1,pathlength - burnin);
for itrans = 1:(pathlength - burnin-1)
% endoStateTemp = endoState(iTrans);
endostatetemp = endostate(itrans);
exostatetemp = exostate(itrans);
tempX = [1 ...
    ,log(endostatetemp)...
    ,log(exostatetemp)...
    ,log(endostatetemp)*log(exostatetemp)...
    ];
tempVal = coeff'*tempX';
recovered(itrans) = exp(tempVal);
end

samplePeriod = 500:1000;
figure;
plot(samplePeriod,endoprice(samplePeriod),'Color','red','LineWidth',1.5);hold on;
plot(samplePeriod,recovered(samplePeriod),'Color','blue','LineStyle','--','LineWidth',1.5);
legend("True LoM","Linear LoM","location","best","FontSize",15)
location = ['../figures/lom_w.pdf'];
saveas(gcf, location);


