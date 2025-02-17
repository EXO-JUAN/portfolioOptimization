%% Optimizing asset allocation
%  
% For a given "risk tolerance" q, with domain [0, inf), 
% optimizing the allocation by constructing the efficient frontier.

% The frontier is found by minimizing the following function:
%       w'*SIGMA*w - q*r'w
%

% Setup data
period     = input('Period (d/w/m): ', 's');
loadfile = strcat(period,'partition');
load (loadfile);      

if strcmpi(period, 'd')
  period = 'Daily';
elseif strcmpi(period, 'w')  
  period = 'Weekly';
elseif strcmpi(period, 'm')
  period = 'Monthly';  
end

AssetList = asset.Return.Properties.VarNames(2:end-3);
pReturns = double(asset.Return(:,AssetList));
Date = asset.Return.Date;

DJReturns = asset.Return.DJI;
SP500Returns = asset.Return.SP500;

% market return and risk
djRet = mean(DJReturns);  
djRsk = std(DJReturns);   
stat = dataset({cellstr('Dow Jones'), 'Portfolio'},{djRet, 'Return'}, {djRsk, 'Risk'});

spRet = mean(SP500Returns);  
spRsk = std(SP500Returns);   
stat = vertcat(stat, dataset({cellstr('SP 500'), 'Portfolio'},{spRet, 'Return'}, {spRsk, 'Risk'}) );


% Create a Portfolio object and estimate the mean and covariance of asset returns
p = Portfolio('AssetList', AssetList);
p = p.estimateAssetMoments(pReturns);

% Set up an equal-weight initial portfolio
p = p.setInitPort(1/p.NumAssets);
[ersk, eret] = p.estimatePortMoments(p.InitPort);
stat = vertcat(stat, dataset({cellstr('Equal-weight'), 'Portfolio'},{eret, 'Return'}, {ersk, 'Risk'}) );

% Plot the distribution of risk and return for the assets in the
% universe along with Dow Jones, SP500, and equal-weight risks and returns.
title = strcat(period, ' Returns vs Risk ');
mv_plot(title, ...
	{'scatter', djRsk, djRet, {'Down Jones'}}, ...
	{'scatter', spRsk, spRet, {'SP 500'}}, ...
	{'scatter', ersk, eret, {'Equal'}}, ...
	{'scatter', sqrt(diag(p.AssetCovar)), p.AssetMean, p.AssetList, '.r'});

stat = vertcat(stat, dataset({p.AssetList', 'Portfolio'},{p.AssetMean, 'Return'}, {sqrt(diag(p.AssetCovar)), 'Risk'}) );
disp(stat);
pause;

k = input('Enter number of optimal portfolios: ');

% Set up a portfolio optimization problem using setDefaultConstraints method.
% here fully-invested long-only portfolios . 
p = p.setDefaultConstraints;

% Estimate the efficient frontier (50 efficient portfolios) 
pwgt = p.estimateFrontier(k);

% estimatePortMoments estimates risks and returns for portfolios. 
[prsk, pret] = p.estimatePortMoments(pwgt);

title = strcat(period, ' Optimal Portfolios vs. Market vs. Equal-weight ');
% mv_plot(title, ...
%   	{'line', prsk, pret}, ...
%   	{'scatter', [djRsk, spRsk, ersk], [djRet, spRet, eret], {'DJI', 'SP500', 'Equal'}}, ...
%   	{'scatter', sqrt(diag(p.AssetCovar)), p.AssetMean, p.AssetList, '.r'});
% pause;

fmt  = cell(1,k);
for i = 1:k
  fmt(1,i) = {num2str(i)};
end

mv_plot(title, ...
	{'line', prsk, pret}, ...
	{'scatter', [djRsk, spRsk, ersk], [djRet, spRet, eret], {'Dow Jones', 'SP 500', 'Equal'}}, ...
	{'scatter', prsk, pret, fmt}, ...
	{'scatter', sqrt(diag(p.AssetCovar)), p.AssetMean, p.AssetList, '.r'});
  

for i = 1:k
  optimalWeight =  pwgt(:,i);
  optimalPort = dataset({100*optimalWeight(optimalWeight > 0),'Weight'}, 'obsnames', p.AssetList(optimalWeight > 0));
  fprintf('optimal %d, return %5.2f, risk %5.2f \n', i, pret(i), prsk(i));
  disp(optimalPort);
end

stat = vertcat(stat, dataset({repmat(cellstr('Optimal'), k,1), 'Portfolio'},{pret, 'Return'}, {prsk, 'Risk'}));
fprintf(' Return and Risk for optimal portfolios vs others \n');
file_name = strcat(period, 'ReturnsVsRisk.csv');
export(stat,'file',file_name,'Delimiter',',');
display(stat);
pause;

%% Find a portfolio with a targeted return and targeted risk
% Given the range of risks and returns, show the location of portfolios on the efficient
% frontier that have target values for return and risk 
[rsk, ret] = p.estimatePortMoments(p.estimateFrontierLimits);
targetRetLabel = strcat('Enter ', period, ' targeted return: ');
targetReturn = input(targetRetLabel);

targetRskLabel = strcat('Enter ', period, ' targeted risk: ');
targetRisk = input(targetRskLabel);

weight1 = p.estimateFrontierByReturn(targetReturn);
[arsk, aret] = p.estimatePortMoments(weight1);

weight2 = p.estimateFrontierByRisk(targetRisk);
[brsk, bret] = p.estimatePortMoments(weight2);

% Plot efficient frontier with targeted portfolios
targetPortTitle = strcat(period, 'Efficient Frontier with Targeted Portfolios');
mv_plot(targetPortTitle, ...
	{'line', prsk, pret}, ...
	{'scatter', [djRsk, spRsk, ersk], [djRet, spRet, eret], {'Dow Jones', 'SP 500', 'Equal'}}, ...
	{'scatter', arsk, aret, {sprintf('%g%% Return',targetReturn)}}, ...
	{'scatter', brsk, bret, {sprintf('%g%% Risk',targetRisk)}}, ...
	{'scatter', sqrt(diag(p.AssetCovar)), p.AssetMean, p.AssetList, '.r'});

%% Setup dataset containing portfolio weights and asset names
targetRetPortfolios = dataset({100*weight1(weight1 > 0),'Weight'}, 'obsnames', p.AssetList(weight1 > 0));
fprintf('%s portfolio with %g%% target return\n', period, targetReturn);
disp(targetRetPortfolios);

targetRiskPortfolios = dataset({100*weight2(weight2 > 0),'Weight'}, 'obsnames', p.AssetList(weight2 > 0));
fprintf('%s portfolio with %g%% target risk\n', period, targetRisk);
disp(targetRiskPortfolios);
