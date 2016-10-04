"""
# Summary:
checkOptions : Checking of input parameters and options for NLEQ1.
"""
function checkOptions(n, x, xScal, opt)

    # TODO: Get the type of elements in x

    # Check whether warnings need to be printed
    printWarn = getOption!(opt,OPT_PRINTWARNING,0)
    printIOwarn = getOption!(opt,OPT_PRINTIOWARN,STDOUT)

    # Get the machine related constants
    great   = 1.0/small

    # Initialize return code to 0
    retCode = 0

    # Check dimensional parameter n
    if n <= 0
        retCode = 20
        write(printIOwarn,"ERROR: Bad input to dimensional parameter n supplied","\n",
            "Choose n positive, your input is: n = $n")
        return retCode
    end

    # Problem type specification by user
    nonLin = getOption(opt,OPT_NONLIN,0)
    if nonLin == 0
        nonLin = 3
        setOption!(opt,OPT_NONLIN,nonLin)
    end

    # Checking and conditional adaptation of user given RTOL
    # if RTOL is not set, set it to 1e-6
    rTol = getOption!(opt,OPT_RTOL,1e-6)
    if rTol <= 0.0
        retCode = 21
        write(printIOwarn,"ERROR: Nonpositive $OPT_RTOL supplied")
        return retCode
    else
        tolMin = epMach*10.0*n
        if rTol < tolMin
            rTol = tolMin
            setOption!(opt,OPT_RTOL,rTol)
            if printWarn == 1
                write(printIOwarn,"WARNING: User prescribed $OPT_RTOL increased to a reasonable smallest value RTOL = $rTol")
            end
        end

        tolMax = 1.0e-1
        if rTol > tolMax
            rTol = tolMax
            setOption!(opt,OPT_RTOL,rTol)
            if printWarn == 1
                write(printIOwarn,"WARNING: User prescribed $OPT_RTOL decreased to a reasonable largest value RTOL = $rTol")
            end
        end
    end

    # Test user prescribed accuracy and scaling on proper values
    if nonLin >= 3
        defScal = rTol
    else
        defScal = 1.0
    end

    for i = 1:n
        # Scaling Values cannot be negative
        # Positive scaling values give scale invariance
        if xScal[i] < 0.0
            retCode = 22
            write(printIOwarn,"ERROR: Negative value in xScal[$i] supplied")
            return retCode
        end

        if xScal[i] == 0.0
            xScal[i] = defScal
        end
        # Avoid overflow due to division by xScal[i]
        if xScal[i] > 0.0 && xScal[i] < small
            if printWarn == 1
                write(printIOwarn,"WARNING: xScal[$i] = $xScal[i] too small, increased to $small")
            end
            xScal[i] = small
        end
        # Avoid underflow due to division by xScal[i]
        if xScal[i] > great
            if printWarn == 1
                write(printIOwarn,"WARNING: xScal[$i] = $xScal[i] too big, increased to $great")
            end
            xScal[i] = great
        end
    end

    # Assign the Jacobian depending on user input
    # Multiple dispatch calls the required function based on
    # the storage requirement of the user
    jacGen = getOption!(opt,OPT_JACGEN,0)
    if jacGen == 1
        jacFcn = getOption!(opt,OPT_JACFCN,0)
        if jacFcn == 0
            retCode = 99
            write(printIOwarn,"ERROR: The Jacobian function OPT_JACFCN is not supplied. ",
            "Please supply a Jacobian function or use OPT_JACGEN = 2 or 3 for numerical differentiation based jacobian evaluation.")
            return retCode
        end
    elseif jacGen == 0
        jacGen = 2
        opt.options[OPT_JACGEN] = jacGen
    end

    # TODO: Add check for IO

    return retCode
end

function initializeOptions(opt, wk, n, m1, nBroy, qRank1, solver)
    # Initialize options
    initOption!(opt, OPT_FCMIN,     0.0)
    initOption!(opt, OPT_SIGMA,     0.0)
    initOption!(opt, OPT_SIGMA2,    0.0)
    initOption!(opt, OPT_NOROWSCAL, 0)

    # Workspace: WK
    if solver == 1
        initOption!(wk, WK_A, zeros(m1,n))
        if qRank1
            initOption!(wk, WK_DXSAVE, zeros(n,nBroy))
        else
            initOption!(wk, WK_DXSAVE, 0.0)
        end
    elseif solver == 2
        initOption!(wk, WK_QU, zeros(n))
        initOption!(wk, WK_A, zeros(n,n))
        if nBroy != 0
            initOption!(wk, WK_QA_DXSAVE, zeros(n,n))
        end
    end

    # Initialize temporary workspace
    initOption!(wk, WK_DX  , zeros(n))
    initOption!(wk, WK_DXQ , zeros(n))
    initOption!(wk, WK_XA  , zeros(n))
    initOption!(wk, WK_XWA , zeros(n))
    initOption!(wk, WK_F   , zeros(n))
    initOption!(wk, WK_FA  , zeros(n))
    initOption!(wk, WK_ETA , zeros(n))
    initOption!(wk, WK_XW  , zeros(n))
    initOption!(wk, WK_FW  , zeros(n))
    initOption!(wk, WK_DXQA, zeros(n))

    return nothing
end

function printInitialization(n, printIOmon, rTol, jacGen, mStor, ml, mu,
    qNoRowScal, qRank1, nonLin, qBDamp, fcBand, qOrdi, qSimpl, nItmax)
    message = ""
    write(printIOmon,"\nINFO: ","N = $n\n")
    write(printIOmon,"\nINFO: ","Prescribed relative precision ",
    "$rTol\n")
    if jacGen == 1
        message = "a user function"
    elseif jacGen == 2
        message = "numerical differentation (without feedback strategy)"
    elseif jacGen == 3
        message = "numerical differentation (feedback strategy included)"
    end
    write(printIOmon,"\nINFO: ","The Jacobian is supplied by $message\n")
    if mStor == 0
        message = "full"
    elseif mStor == 1
        message = "banded"
    end
    write(printIOmon,"INFO: ","The Jacobian will be stored in $message mode\n")
    if mStor == 1
        write(printIOmon,"INFO: ","Lower bandwidth : $ml \t",
        "Upper bandwidth : $mu\n")
    end
    if qNoRowScal == 1
        message = "inhibited"
    else
        message = "allowed"
    end
    write(printIOmon,"INFO: ",
    "Automatic row scaling of the jacobian is $message\n")

    if qRank1
        message = "allowed"
    else
        message = "inhibited"
    end
    write(printIOmon,"\nINFO: ","Rank-1 updates are $message\n")
    if nonLin == 1
        message = "linear"
    elseif nonLin == 2
        message = "mildly nonlinear"
    elseif nonLin == 3
        message = "highly nonlinear"
    elseif nonLin == 4
        message = "extremely nonlinear"
    end
    write(printIOmon,"INFO: ","Problem is specified as being $message\n")
    if qBDamp
        write(printIOmon,"INFO: ","Bounded damping strategy is active\n",
        "bounding factor is $fcBand\n")
    else
        write(printIOmon,"INFO: ","Bounded damping strategy is off\n")
    end
    if qOrdi
        write(printIOmon,"INFO: ","Special mode: ",
        "Ordinary Newton iteration will be done\n")
    end
    if qSimpl
        write(printIOmon,"INFO: ","Special mode: ",
        "Simplified Newton iteration will be done\n")
    end

    write(printIOmon,"INFO: ","Maximum permitted number of ",
    "iteration steps : $nItmax\n")
end

function printStats(stats, printIOmon)
    write(printIOmon,"\n",
    @sprintf("*************   Statistics   ************\n"),
    @sprintf("***  Newton-iterations     : %7i  ***\n", (stats[STATS_NITER])),
    @sprintf("***  Corrector steps       : %7i  ***\n", (stats[STATS_NCORR])),
    @sprintf("***  Rejected Rank-1 steps : %7i  ***\n", (stats[STATS_NREJR1])),
    @sprintf("***  Jacobian evaluations  : %7i  ***\n", (stats[STATS_NJAC])),
    @sprintf("***  Function evaluations  : %7i  ***\n", (stats[STATS_NFCN])),
    @sprintf("***  ... for Jacobain eval : %7i  ***\n", (stats[STATS_NFCNJ])),
    @sprintf("*****************************************\n"))
end

# TODO: Get printIO from call rather than inside function
function nScal(n, x, xa, xScal, iScal, qIniSc, opt, xw)
    # Begin
    if iScal == 1
        xw[:] = xScal
    else
        for l1 = 1:n
            xw[l1] = max(xScal[l1],max((abs(x[l1])+abs(xa[l1]))*0.5,small))
        end
    end

    mPr = opt.options[OPT_PRINTITERATION]
    if mPr >= 6
        printIO = opt.options[OPT_PRINTIO]
        write(printIO,"\n\n",
        "+++++++++++++++++++++++++++++++++++++++++++++++++\n",
        "      x-components         scaling-components\n")
        for l1 = 1:n
            write(printIO,"  %18.10e   %18.10e\n",x[l1],xw[l1])
        end
        write(printIO,"+++++++++++++++++++++++++++++++++++++++++++++++++\n\n")
    end
    return nothing
end

function nScrf(m,n,a,fw)
    # Begin
    if issparse(a)
        nza = nnz(a)
        (row,col) = findn(a)
        aout = sparse(row,col,zeros(nza),m,n)
        for j = 1:nza
            rj = row[j]
            aaj = abs(a[rj,col[j]])
            fw[rj] = max(fw[rj],aaj)
        end
        for k = 1:m
            if fw[k] > 0.0
                fw[k] = 1.0/fw[k]
            else
                fw[k] = 1.0
            end
        end
        for j = 1:nza
            aout[row[j],col[j]] = a[row[j],col[j]]*fw[row[j]]
        end
    else
        aout = zeros(a)
        for k = 1:m
            s1 = maximum(abs(a[k,1:n]))
            if s1 > 0.0
                s1 = 1.0/s1
                fw[k] = s1
                aout[k,1:n] = a[k,1:n]*s1
            else
                fw[k] = 1.0
                aout[k,1:n] = a[k,1:n]
            end
        end
    end
    a[:] = aout
end

function nScrb(n,lda,ml,mu,a,fw)
    # Begin
    aout = zeros(a)
    m2 = ml + mu + 1
    for k = 1:n
        s1 = 0.0
        l2 = max(1,k-ml)
        l3 = min(n,k+mu)
        k1 = m2 + k
        for l1 = l2:l3
            s1 = max(s1,abs(a[k1-l1,l1]))
        end
        if s1 > 0.0
            s1 = 1.0/s1
            fw[k] = s1
            for l1 = l2:l3
                aout[k1-l1,l1] = a[k1-l1,l1]*s1
            end
        else
            fw[k] = 1.0
        end
    end
    a[:] = aout
end

function nLvls(n,dxq,dx1,xw,f,mPr,qdscal)
    # Begin
    if qdscal
        # ----------------------------------------------------------------------
        # 1.2 Descaling of solution dx1 (stored to dxq)
        dxq[:] = dx1.*xw
    end
    # --------------------------------------------------------------------------
    # 2 Evaluation of scaled natural level function sumx and scaled maximum
    # error norm conv
    conv = maximum(abs(dx1))
    sumx = sum(dx1.^2)
    # --------------------------------------------------------------------------
    # 3 Evaluation of (scaled) standard level function dlevf
    dlevf = sqrt(sum(f.^2)/n)
    return (conv,sumx,dlevf)
end


function nPrv2(dlevf,dlevx,fc,niter,mPr,printIO,qMixIO,cmark)
    if qMixIO
        write(printIO,"  ******************************************************************",
        "\n");
        write(printIO,"        It       Normf           Normx         Damp.Fct.\n")
    end
    write(printIO,@sprintf("      %4i     %10.3e    %1s %10.3e      %7.5f\n",niter,dlevf,cmark,dlevx,fc))
    if qMixIO
        write(printIO,"  ******************************************************************",
        "\n");
    end
    return nothing
end

function nSout(n, x, mode, opt, mPr, printIO, nIter, dLevF, sumX)
    # Begin
    qNorm = true
    if qNorm
        if mode == 1
            write(printIO,@sprintf("\n%s\n%s%5i\n\n%s\n","  Start data:","  N =",n,
                "  Format: iteration-number, (x(i),i=1,...N) , Normf , Normx "))
            write(printIO,@sprintf("%s\n","  Initial data:"))
        elseif mode == 3
            write(printIO,@sprintf("%s\n","  Solution data:"))
        elseif mode == 4
            write(printIO,@sprintf("%s\n","  Final data:"))
        end
        write(printIO,@sprintf(" %5i\n",nIter))
        l2 = 0
        for l1 = 1:n
            write(printIO,@sprintf("%18.10e ",x[l1]))
            l2 += 1
            if l2 == 3
                write(printIO," \n")
                l2 = 0
            end
        end
        write(printIO,@sprintf("%18.10e %18.10e \n",dLevF,
            sqrt(sumX/n)))
        if mode == 1 && mPr >= 2
            write(printIO,@sprintf("%s\n","  Intermediate data:"))
        elseif mode >= 3
            write(printIO,@sprintf("%s\n","  End data:"))
        end
    end
    return nothing
end

function wnorm(n,z,xw)
    # Begin
    return sqrt(sum((z./xw).^2)/n)
end
