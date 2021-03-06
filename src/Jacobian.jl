"""
function nJacFD{T}(fcn, n::Int64, lda::Int64, x::Vector{T}, fx::Vector{T},
    yscal::Vector{T}, ajdel::T, ajmin::T, nFcn::Int64,
    a::Array{T,2})

Evaluation of a dense Jacobian matrix using finite difference approximation
adapted for use in nonlinear systems solver.

T = Float64 or BigFloat

## Input parameters
-------------------
| Variable | Description                                                     |
|:---------|:----------------------------------------------------------------|
| fcn      | Function of the form fcn(f, x) to provide right-hand side       |
| n        | Number of rows and columns of the Jacobian                      |
| lda      | Leading dimension of the array "a"                              |
| x[n]     | Current scaled vector                                           |
| fx[n]    | Vector containing fcn(x)                                        |
| yscal[n] | Vector containing scaling factors                               |
| ajdel    | Perturbation of component k: abs(y(k))*ajdel                    |
| ajmin    | Minimum perturbation is ajmin*ajdel                             |
| nFcn*    | fcn evaluation count                                            |

(* marks inout parameters)

## Output parameters
-------------------
| Variable | Description                                                     |
|:---------|:----------------------------------------------------------------|
| a[lda,n] | Array containing the approximated Jacobian                      |
| nFcn*    | fcn evaluation count adjusted                                   |
| iFail    | Return code non-zero if Jacobian could not be computed          |
"""
function nJacFD{T}(fcn, n::Int64, lda::Int64, x::Vector{T}, fx::Vector{T},
    yscal::Vector{T}, ajdel::T, ajmin::T, nFcn::Int64,
    a::Array{T,2})
    # Begin
    # Copy for internal purposes
    xa = x[:]
    iFail = 0
    fu = zero(x)
    for k = 1:n
        w = xa[k]
        su = sign(xa[k])
        if su == 0
            su = 1
        end
        u = max(max(abs(xa[k]),ajmin),yscal[k])*ajdel*su;
        xa[k] = w + u
        try
            fcn(fu,xa)
        catch
            iFail = -1
        end
        nFcn += 1
        if iFail != 0
            break
        end
        xa[k] = w
        a[1:n,k:k] = (fu-fx)./u
    end
    return (nFcn, iFail)
end

"""
function nJacFDb{T}(fcn, n::Int64, lda::Int64, ml::Int64, x::Vector{T},
    fx::Vector{T}, yscal::Vector{T}, ajdel::T, ajmin::T,
    nFcn::Int64, a::Array{T,2})

Evaluation of a banded Jacobian matrix using finite difference approximation
adapted for use in nonlinear systems solver

T = Float64 or BigFloat

## Input parameters
-------------------
| Variable | Description                                                     |
|:---------|:----------------------------------------------------------------|
| fcn      | Function of the form fcn(f, x) to provide right-hand side       |
| n        | Number of rows and columns of the Jacobian                      |
| lda      | Leading dimension of the array "a"                              |
| ml       | Lower bandwidth of the Jacobian matrix                          |
| x[n]     | Current scaled vector                                           |
| fx[n]    | Vector containing fcn(x)                                        |
| yscal[n] | Vector containing scaling factors                               |
| ajdel    | Perturbation of component k: abs(y(k))*ajdel                    |
| ajmin    | Minimum perturbation is ajmin*ajdel                             |
| nFcn*    | fcn evaluation count                                            |

(* marks inout parameters)

## Output parameters
-------------------
| Variable | Description                                                     |
|:---------|:----------------------------------------------------------------|
| a[lda,n] | Array containing the approximated Jacobian                      |
| nFcn*    | fcn evaluation count adjusted                                   |
| iFail    | Return code non-zero if Jacobian could not be computed          |
"""
function nJacFDb{T}(fcn, n::Int64, lda::Int64, ml::Int64, x::Vector{T},
    fx::Vector{T}, yscal::Vector{T}, ajdel::T, ajmin::T,
    nFcn::Int64, a::Array{T,2})
    # Begin
    # Copy for internal purposes
    xa = x[:]
    iFail = 0
    mu = lda - 2*ml -1
    ldab = ml + mu + 1
    fu = zero(x)
    w  = zero(x)
    u  = zero(x)
    for jj = 1:ldab
        for k = jj:ldab:n
            w[k] = xa[k]
            su = sign(xa[k])
            if su == 0
                su = 1
            end
            u[k]  = max(max(abs(xa[k]),ajmin),yscal[k])*ajdel*su
            xa[k] = w[k] + u[k]
        end
        try
            fcn(fu,xa)
        catch
            iFail = -1
        end
        nFcn += 1
        if iFail != 0
            break;
        end
        for k = jj:ldab:n
            xa[k] = w[k]
            i1 = max(1,k-mu)
            i2 = min(n,k+ml)
            mh = mu + 1 - k
            a[mh+i1:mh+i2,k:k] = (fu[i1:i2]-fx[i1:i2])/u[k]
        end
    end
    return (nFcn,iFail)
end

"""
function nJcf{T}(fcn, n::Int64, lda::Int64, x::Vector{T}, fx::Vector{T},
    yscal::Vector{T}, eta::Vector{T}, etamin::T, etamax::T,
    etadif::T, conv::T, nFcn::Int64, a::Array{T,2})

Approximation of dense Jacobian matrix for nonlinear systems solver with
feed-back control of discretization and rounding errors

T = Float64 or BigFloat

## Input parameters
-------------------
| Variable | Description                                                     |
|:---------|:----------------------------------------------------------------|
| fcn      | Function of the form fcn(f, x) to provide right-hand side       |
| n        | Number of rows and columns of the Jacobian                      |
| lda      | Leading dimension of the array "a"                              |
| x[n]     | Current scaled vector                                           |
| fx[n]    | Vector containing fcn(x)                                        |
| yscal[n] | Vector containing scaling factors                               |
| eta[n]*  | Vector of scaled denominator differences                        |
| etamin   | Minimum allowed scaled denominator                              |
| etamax   | Maximum allowed scaled denominator                              |
| etadif   | = sqrt(1.1*epMach)                                              |
| conv     | Maximum norm of last (unrelaxed) Newton correction              |
| nFcn*    | fcn evaluation count                                            |

(* marks inout parameters)

## Output parameters
-------------------
| Variable | Description                                                     |
|:---------|:----------------------------------------------------------------|
| a[lda,n] | Array containing the approximated Jacobian                      |
| eta[n]*  | Vector of scaled denominator differences adjusted               |
| nFcn*    | fcn evaluation count adjusted                                   |
| iFail    | Return code non-zero if Jacobian could not be computed          |
"""
function nJcf{T}(fcn, n::Int64, lda::Int64, x::Vector{T}, fx::Vector{T},
    yscal::Vector{T}, eta::Vector{T}, etamin::T, etamax::T,
    etadif::T, conv::T, nFcn::Int64, a::Array{T,2})
    # Constant
    small2 = 0.1
    # Copy for internal purposes
    xa = x[:]
    # Begin
    fu = zero(x)
    iFail = 0
    for k = 1:n
        is = 0
        qFine = false
        qExit = false
        while !qFine
            w = xa[k]
            su = sign(xa[k])
            if su == 0
                su = 1
            end
            u = eta[k]*yscal[k]*su
            xa[k] = w + u
            try
                fcn(fu,xa)
            catch
                iFail = -1
            end
            nFcn += 1
            if iFail != 0
                qExit = true
                break;
            end
            xa[k] = w
            sumd = 0.0
            for i = 1:n
                hg = max(abs(fx[i]),abs(fu[i]))
                fhi = fu[i] - fx[i]
                if hg != 0.0
                    sumd = sumd + (fhi/hg)^2
                end
                a[i,k] = fhi/u
            end
            sumd = sqrt(sumd/n)
            qFine = true
            if sumd != 0.0 && is == 0
                eta[k] = min(etamax,max(etamin,sqrt(etadif/sumd)*eta[k]))
                is = 1
                qFine = conv < small2 || sumd >= etamin
            end
        end
        if qExit
            break;
        end
    end
    return (nFcn,iFail)
end

"""
function nJcfb{T}(fcn, n::Int64, lda::Int64, ml::Int64, x::Vector{T},
    fx::Vector{T}, yscal::Vector{T}, eta::Vector{T},
    etamin::T, etamax::T, etadif::T, conv::T,
    nFcn::Int64, a::Array{T,2})

Approximation of banded Jacobian matrix for nonlinear systems solver with
feed-back control of discretization and rounding errors

T = Float64 or BigFloat

## Input parameters
-------------------
| Variable | Description                                                     |
|:---------|:----------------------------------------------------------------|
| fcn      | Function of the form fcn(f, x) to provide right-hand side       |
| n        | Number of rows and columns of the Jacobian                      |
| lda      | Leading dimension of the array "a"                              |
| ml       | Lower bandwidth of the Jacobian matrix                          |
| x[n]     | Current scaled vector                                           |
| fx[n]    | Vector containing fcn(x)                                        |
| yscal[n] | Vector containing scaling factors                               |
| eta[n]*  | Vector of scaled denominator differences                        |
| etamin   | Minimum allowed scaled denominator                              |
| etamax   | Maximum allowed scaled denominator                              |
| etadif   | = sqrt(1.1*epMach)                                              |
| conv     | Maximum norm of last (unrelaxed) Newton correction              |
| nFcn*    | fcn evaluation count                                            |

(* marks inout parameters)

## Output parameters
-------------------
| Variable | Description                                                     |
|:---------|:----------------------------------------------------------------|
| a[lda,n] | Array containing the approximated Jacobian                      |
| eta[n]*  | Vector of scaled denominator differences adjusted               |
| nFcn*    | fcn evaluation count adjusted                                   |
| iFail    | Return code non-zero if Jacobian could not be computed          |
"""
function nJcfb{T}(fcn, n::Int64, lda::Int64, ml::Int64, x::Vector{T},
    fx::Vector{T}, yscal::Vector{T}, eta::Vector{T},
    etamin::T, etamax::T, etadif::T, conv::T,
    nFcn::Int64, a::Array{T,2})
    # Constants
    small2 = 0.1
    # Copy for internal purposes
    xa = x[:]
    # Begin
    mu = lda - 2*ml - 1
    ldab = ml + mu + 1
    fu = zero(x)
    w  = zero(x)
    u  = zero(x)
    iFail = 0
    for jj = 1:ldab
        is = 0
        qFine = false
        qExit = false
        while !qFine
            for k = jj:ldab:n
                w[k] = xa[k]
                su = sign(xa[k])
                if su == 0
                    su = 1
                end
                u[k] = eta[k]*yscal[k]*su
                xa[k] = w[k] + u[k]
            end

            try
                fcn(fu,xa)
            catch
                iFail = -1
            end
            nFcn += 1
            if iFail != 0
                qExit = true
                break;
            end

            for k = jj:ldab:n
                xa[k] = w[k]
                sumd = 0.0
                i1 = max(1,k-mu)
                i2 = min(n,k+ml)
                mh = mu + 1 - k
                for i = i1:i2
                    hg = max(abs(fx[i]),abs(fu[i]))
                    fhi = fu[i] - fx[i]
                    if hg != 0.0
                        sumd += (fhi/hg)^2
                    end
                    a[mh+i,k:k] = fhi/u[k]
                end
                sumd = sqrt(sumd/n)
                qFine = true
                if sumd != 0.0 && is == 0
                    eta[k] = min(etamax,max(etamin,sqrt(etadif/sumd)*eta[k]))
                    is = 1
                    qFine = conv < small2 || sumd >= etamin
                end
            end
        end
        if qExit
            break;
        end
    end
    return (nFcn,iFail)
end
