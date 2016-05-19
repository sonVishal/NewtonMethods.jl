include("NLEQ1.jl")
function f(x)
    x = x-1;
    return nothing;
end

function Jac(x,y)
    y[1] = x[1]+2
    y[2] = x[2]+3;
    return nothing;
end

opt = OptionsNLEQ(OPT_PRINTWARNING => 1, OPT_PRINTITERATIONMON => 2, OPT_RTOL => 1)
wk  = OptionsNLEQ()

x = ones(4);
xScal = ones(4);

(stats,retCode) = nleq1(f,x,xScal,opt,wk);

println("retCode = $retCode","\n");
println("Options = $opt","\n");

# throw(InvalidOption("OPT_RTOL",-2))

println("2")
