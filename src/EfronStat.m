classdef EfronStat < dynamicprops

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    properties
        thresh
        ndata
        logx
        logy
        logxMax
        %logyMin
        logxDistanceFromLogThresh
        logyDistanceFromLogThresh
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    methods(Access=public)

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        function self = EfronStat(logx, logy, observerLogThresh, threshType)

            self.ndata = length(logx);
            if self.ndata~=length(logy)
                error("ndata~=length(y): " + string(logx) + " " + string(logy) );
            end
            if nargin~=4
                error   ( "Incorrect number of input arguments. Usage:" ...
                        + newline ...
                        + "    EfronStat(xdata, ydata, observerLogThresh, threshType)" ...
                        );
            end

            self.logx = logx;
            self.logy = logy;
            self.thresh = Thresh(observerLogThresh, threshType);

            % compute Efron stat

            disp("computing the Efron Petrosian Statistics for the log-detection threshold limit of " + string(observerLogThresh) + " ...");
            self.logxMax = self.getLogxMaxTau();

            % compute the regression alpha and its 1-sigma uncertainty

            self.logxMax.alpha.tau.zero = self.getLogxMaxAlphaGivenTau(0);
            self.logxMax.alpha.tau.posOne = self.getLogxMaxAlphaGivenTau(1);
            self.logxMax.alpha.tau.negOne = self.getLogxMaxAlphaGivenTau(-1);

            % compute distances of data from the detector threshold

            self.getLogxDistanceFromLogThresh();
            self.getLogyDistanceFromLogThresh();

        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        function logxMaxAtThresh = getLogxMaxAtThresh(self)
            logxMaxAtThresh = zeros(self.ndata,1);
            for i = 1:self.ndata
                getLogThreshInt = @(logxDum) abs(self.thresh.getLogValInt(logxDum) - self.logy(i));
                options = optimset("MaxIter", 10000, "MaxFunEvals", 10000);
                [x, funcVal, exitflag, output] = fminsearch(getLogThreshInt, self.logx(i), options);
                if exitflag==1
                    logxMaxAtThresh(i) = x;
                else
                    disp( "failed at iteration " + string(i) + " with logx(i) = " + string(self.logx(i)) + ...
                        + ", logy(i) = " + string(self.logy(i)) + " with fval = " + string(fval) ...
                        );
                    disp("i = " + string(i));
                    disp("self.logx(i) = " + string(self.logx(i)));
                    disp("self.logy(i) = " + string(self.logy(i)));
                    disp("funcVal = " + string(funcVal));
                    disp("output = " + string(output));
                end
            end
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        function logyMinAtThresh = getLogyMinAtThresh(self)
            logyMinAtThresh = self.thresh.getLogValInt(self.logx);
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        function logxMax = getLogxMaxTau(self,logyLocal)

            if nargin<2; logyLocal = self.logy; end

            logxMax = struct();
            logxMax.val = self.getLogxMaxAtThresh(); % vector of size (ndata,1) containing maximum x value at the detection threshold
            logxMax.box = cell(self.ndata,1);

            tauNumerator = 0.;
            tauDenominatorSq = 0.;
            for i = 1:self.ndata

                logxMax.box{i} = struct();
                logxMax.box{i}.mask = self.logx <= logxMax.val(i) & logyLocal >= logyLocal(i);
                logxMax.box{i}.count = sum( logxMax.box{i}.mask );
                logxMax.box{i}.logx = self.logx( logxMax.box{i}.mask );
                logxMax.box{i}.logy = self.logx( logxMax.box{i}.mask );
                logxMax.box{i}.rank.val = sum( logxMax.box{i}.logx < self.logx(i) );
                logxMax.box{i}.rank.avg = ( logxMax.box{i}.count + 1 ) * 0.5;
                logxMax.box{i}.rank.var = ( logxMax.box{i}.count ^ 2 - 1 ) / 12.;
                tauNumerator = tauNumerator + logxMax.box{i}.rank.val - logxMax.box{i}.rank.avg;
                tauDenominatorSq = tauDenominatorSq + logxMax.box{i}.rank.var;

            end

            logxMax.tau = tauNumerator / sqrt( tauDenominatorSq );

        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        function tauGivenAlpha = getLogxMaxTauGivenAlpha(self,alpha)
            logyLocal = self.logy - alpha*self.logx;
            logxMax = self.getLogxMaxTau(logyLocal);
            tauGivenAlpha = logxMax.tau;
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        function logxMaxAlphaGivenTau = getLogxMaxAlphaGivenTau(self,tau)
            % compute the negative linear regression slope of the logx-logy relationship
            getLogxMaxAlphaGivenTauHandle = @(alpha) abs(self.getLogxMaxTauGivenAlpha(alpha) - tau);
            options = optimset("MaxIter", 10000, "MaxFunEvals", 10000, "TolX", 5.e-3, "TolFun", 1.e-2);
            [logxMaxAlphaGivenTau, funcVal, exitflag, output] = fminsearch(getLogxMaxAlphaGivenTauHandle, 2, options);
            if exitflag~=1
                disp("failed to converge " + " with fval = " + string(fval));
                disp("i = " + string(i));
                disp("self.logx(i) = " + string(self.logx(i)));
                disp("self.logy(i) = " + string(self.logy(i)));
                disp("funcVal = " + string(funcVal));
                disp("output = " + string(output));
            end
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        function getLogyDistanceFromLogThresh(self)
            self.logyDistanceFromLogThresh = self.logy - self.getLogyMinAtThresh();
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        function getLogxDistanceFromLogThresh(self)
            self.logxDistanceFromLogThresh = self.getLogxMaxAtThresh() - self.logx;
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    methods(Hidden)
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

end