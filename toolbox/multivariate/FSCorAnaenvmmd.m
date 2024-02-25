function [MMDenv,CHI2env] = FSCorAnaenvmmd(N,varargin)
%FSCorAnaenvmmd computes the empirical envelopes of Minimum MD outside subset during the search
%
%<a href="matlab: docsearchFS('FSCorAnaenvmmd')">Link to the help function</a>
%
% Required input arguments:
%
%  N :  contingency table or structure.
%               Array or table of size I-by-J or structure. If N is a
%               structure it must contain the fields:
%               N.N =contingency table in array format of size I-by-J (this
%                   field is compulsory).
%               N.NsimStore= array of size I-by-J times nsimul containing
%                   in each column the nsimul simulated contingency tables.
%                   If this field is not present the nsimul simulated
%                   contingency tables are generated by this routine.
%               Note that input structure N can be conveniently created by
%               function mcdCorAna.
%               Data Types - single | double
%
% Optional input arguments:
%
% init :       Point where to start monitoring required diagnostics. Scalar.
%              Note that if bsb is supplied, init>=length(bsb). If init is not
%              specified it will be set equal to floor(n*0.6).
%                 Example - 'init',50
%                 Data Types - double
%
% prob:        quantiles for which envelopes have
%               to be computed. Vector. Vector containing 1 x k elements .
%               The default is to produce 1 per cent, 50 per cent and 99 per cent envelopes.
%                 Example - 'prob',[0.05 0.95]
%                 Data Types - double
%
% nsimul   :   numer of simulations. Scalar.
%              Number of simulations to perform. The default value is 200.
%              Note that this input option is ignored if N is a struct and
%              field N.NsimStore is present. In this last case nsimul is
%              equal to the number of columns of N.NsimStore
%                 Example - 'nsimul',100
%                 Data Types - double

% Output:
%
%  MMDenv :     n-m0+1 x length(prob)+1 columns containing the envelopes
%               for the requested quantiles.
%               1st col = fwd search index from m0 to n-1;
%               2nd col = envelope for quantile prob[1];
%               3rd col = envelope for quantile prob[2];
%               ...;
%               (k+1) col = envelope for quantile prob[k].
%
%  CHI2env :     n-m0+1 x length(prob)+1 columns containing the envelopes
%               for the requested quantiles of inertia explained.
%               1st col = fwd search index from m0 to n1;
%               2nd col = envelope of inertia explained for quantile prob[1];
%               3rd col = envelope of inertia explained for quantile prob[2];
%               ...;
%               (k+1) col = envelope  of inertia explained for quantile prob[k].
%
% See also FSMenvmmd.m, FSM.m
%
% References:
%
% Riani, M., Atkinson, A.C. and Cerioli, A. (2009), Finding an unknown
% number of multivariate outliers, "Journal of the Royal Statistical
% Society Series B", Vol. 71, pp. 201-221.
%
% Copyright 2008-2024.
% Written by FSDA team
%
%
%<a href="matlab: docsearchFS('FSCorAnaenvmmd')">Link to the help function</a>
%
%$LastChangedDate::                      $: Date of the last commit

% Examples:

%
%{
    %% Call of FSCorAnaenvmmd with all the default options.
    % Generate contingency table of size 30-by-5 with total sum of n_ij=3000.
    I=50;
    J=5;
    n=10000;
    % nrowt = column vector containing row marginal totals
    nrowt=(n/I)*ones(I,1);
    % ncolt = row vector containing column marginal totals
    ncolt=(n/J)*ones(1,J);
    out1=rcontFS(I,J,nrowt,ncolt);
    N=out1.m144;
    MMDenv=FSCorAnaenvmmd(N);
    plot(MMDenv(:,1),MMDenv(:,2:4),'k')
    xlabel('Subset size m');
%}

%{
    % Call of FSCorAnaenvmmd with options prob and nsimul.
    % Compute 0.001 0.01 0.99 and 0.999 envelopes
    % Generate contingency table of size 50-by-5 with total sum of n_ij=2000.
    I=50;
    J=5;
    n=2000;
    % nrowt = column vector containing row marginal totals
    nrowt=(n/I)*ones(I,1);
    % ncolt = row vector containing column marginal totals
    ncolt=(n/J)*ones(1,J);
    out1=rcontFS(I,J,nrowt,ncolt);
    N=out1.m144;
    MMDenv=FSCorAnaenvmmd(N,'prob',[0.001 0.01 0.99 0.999],'nsimul',1000);
    hold('on')
    plot(MMDenv(:,1),MMDenv(:,3:4),'r-')
    plot(MMDenv(:,1),MMDenv(:,[2 5]),'k-')
    xlabel('Subset size m')
%}

%{
    % Monitor the inertia explained.
    % Compute 0.01 0.5 0.99 envelopes
    % Generate contingency table of size 20-by-5 with total sum of n_ij=2000.
    I=20;
    J=5;
    n=2000;
    % nrowt = column vector containing row marginal totals
    nrowt=(n/I)*ones(I,1);
    % ncolt = row vector containing column marginal totals
    ncolt=(n/J)*ones(1,J);
    out1=rcontFS(I,J,nrowt,ncolt);
    N=out1.m144;
    [~,INEenv]=FSCorAnaenvmmd(N,'prob',[0.01 0.5 0.99],'nsimul',1000);
    plot(INEenv(:,1),INEenv(:,2:end),'r-')
    xlabel('Subset size m')
%}

%% Beginning of code

% Default value for number of simulations
nsimul=2000;

% Input parameters checks
if isstruct(N)
    if isfield(N,'NsimStore')
        preGeneratedNsim=true;
        NsimStore=N.NsimStore;
        nsimul=size(NsimStore,2);
    else
        preGeneratedNsim=false;
    end
    N=N.N;
else
    preGeneratedNsim=false;
end
if istable(N) || istimetable(N)
    N=table2array(N);
end

[nrow,ncol]=size(N);
n=round(sum(N,'all'));

m0=floor(n*0.6);

% Default quantiles to use
prob=[0.01 0.5 0.99];


if nargin>1
    options=struct('init',m0,'prob',prob,'nsimul',nsimul);

    [varargin{:}] = convertStringsToChars(varargin{:});
    UserOptions=varargin(1:2:length(varargin));
    % Check if number of supplied options is valid
    if length(varargin) ~= 2*length(UserOptions)
        error('FSDA:FSCorAnaenvmmd:WrongInputOpt','Number of supplied options is invalid. Probably values for some parameters are missing.');
    end
    % Check if user options are valid options
    aux.chkoptions(options,UserOptions)
    for i=1:2:length(varargin)
        options.(varargin{i})=varargin{i+1};
    end

    m0=options.init;
    prob=options.prob;
    nsimul=options.nsimul;

    % Check that the initial subset size is not greater than n-1
    if m0>n-1
        error('FSDA:FSMenvmmd:WrongM0',['Initial starting point of the search (m0=' num2str(m0) ') is greater than n-1(n-1=' num2str(n-1) ')']);
    end
end

% Check that the number of simulations is large enough to obtain the
% requested quantiles
sel=round(nsimul*prob);
sel(sel==0)=1;
if ~isequal(unique(sel,"stable"),sel)
    warning('FSDA:FSCorAnaenvmmd:TooLowNsimul',['Some lines are equal it is necessary to' ...
        ' increase the number of simulations. At present the order stats which are selected are']);
    disp(num2str(sel(:)'))
end

%% Envelopes generation


mmdStore=zeros(n-m0,nsimul);
ineStore=zeros(n-m0+1,nsimul);

if preGeneratedNsim ==true
    parfor j=1:nsimul
        Nsim=reshape(NsimStore(:,j),nrow,[]);
        outSIMj=FSCorAnaeda(Nsim,'init',m0);
        mmdStore(:,j)=outSIMj.mmd(:,2);
        ineStore(:,j)=outSIMj.ine(:,2);
    end

else
    % nrowt = column vector containing row marginal totals
    nrowt=round(sum(N,2));
    % ncolt = row vector containing column marginal totals
    ncolt=round(sum(N,1));

    parfor j=1:nsimul

        % Generate the contingency table under H0
        out1=rcontFS(nrow,ncol,nrowt,ncolt,'nocheck',true);
        Nsim=out1.m144;

        RAW=mcdCorAna(Nsim,'plots',0,'msg',0,'nsamp',300);
        outSIMj=FSCorAnaeda(RAW,'init',m0);

        mmdStore(:,j)=outSIMj.mmd(:,2);
        ineStore(:,j)=outSIMj.ine(:,2);
    end
end

% Sort rows of matrix mmdStore
mmdStore=sort(mmdStore,2);

% Sort rows of matrix mmdStore
ineStore=sort(ineStore,2);


MMDenv=[(m0:n-1)',mmdStore(:,sel)];
CHI2env=[(m0:n)',ineStore(:,sel)];
end

%FScategory:MULT-Multivariate

