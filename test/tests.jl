using SymPy
using SpecialFunctions
using SymPy.SpecialFuncs
using Compat.Test

if isdefined(Base, :MathConstants)
    e = Base.MathConstants.e
end

@testset "Core" begin
    ## Symbol creation
    x = Sym("x")
    #x = sym"x" # deprecated
    x = Sym(:x)
    x,y = Sym(:x, :y)
    x,y = symbols("x,y")

    @syms u1 u2 u3
    @syms u positive=true
    @test length(solve(u+1)) == 0
    # make sure @syms defines in a local scope
    let
        @syms w
    end
    @test_throws UndefVarError isdefined(w)
    @vars a b c


    ## extract symbols
    ex = x*y
    @test isa(free_symbols(ex), Vector{Sym})

    ## number conversions
    @test Sym(2) == 2
    @test Sym(2.0) == 2.0
    @test Sym(2//1) == 2
    @test Sym(im) == 1im
    @test Sym(2im) == 2im
    @test Sym(1 + 2im) == 1 + 2im
    
    if isdefined(Base, :MathConstants)
        _pi, _e, _catalan = Base.MathConstants.pi, Base.MathConstants.e, Base.MathConstants.catalan
    else
        _pi, _e, _catalan = pi, e, catalan
    end
    @test N(Sym(_pi)) == Float64(_pi)
    @test N(Sym(_e)) == Float64(_e)
    @test N(Sym(_catalan)) == Float64(_catalan)
        

    ## function conversion
    f1 = convert(Function, x^2)
    @test f1(2) == 4

    ### Subs
    ## subs, |> (x == number)
    f(x) = x^2 - 2
    y = f(x)
    @test float(subs(y, x, 1)) == f(1)
    @test float( y |> subs(x,1) ) == f(1)

    ## interfaces
    ex = (x-1)*(y-2)
    @test subs(ex, x, 1) == 0
    @test subs(ex, (x,1)) == 0
    @test subs(ex, (x,2),(y,2)) == 0

    @test subs(ex, x=>1) == 0
    @test subs(ex, x=>2, y=>2) == 0
    @test subs(ex, Dict(x=>1)) == 0
    @test ex(x=>1) == 0

    ## match, replace, xreplace, rewrite
    x,y,z = symbols("x, y, z")
    a,b,c = map(Wild, (:a,:b,:c))
    ## match: we have pattern, expression to follow `match`
    d = match(a^a, (x+y)^(x+y))
    @test d[a] == x+y
    d = match(a^b, (x+y)^(x+y))
    @test d[b] == x + y
    ex = (2x)^2
    pat = a*b^c
    d = match(pat, ex)
    @test d[a] == 4 && d[b] == x && d[c] == 2
    @test xreplace(pat, d) == 4x^2

    ## replace
    a = Wild("a")
    ex = log(sin(x)) + tan(sin(x^2))
    @test replace(ex, func(sin(x)), func(cos(x))) == log(cos(x)) + tan(cos(x^2))
    #XXX@test replace(ex, func(sin(x)), u ->  sin(2u)) == log(sin(2x)) + tan(sin(2x^2))
    @test replace(ex, sin(a), tan(a)) ==  log(tan(x)) + tan(tan(x^2))
    @test replace(ex, sin(a), a) == log(x) + tan(x^2)
    @test replace(x*y, a*x, a) == y

    ## xreplace
    @test xreplace(1 + x*y, x => PI) == 1 + PI*y
    @test xreplace(x*y + z, x*y => PI) == z + PI
    @test xreplace(x*y * z, x*y => PI) == x* y * z
    @test xreplace(x +2 + exp(x + 2), x+2=>y) == x + exp(y) + 2

    # Test subs on simple numbers
    @syms x y
    @test subs(2, x=>300, y=>1.2) == 2.0

    #Test subs for pars and dicts
    ex = 1
    dict1 = Dict{String,Any}()
    dict2 = Dict{Any,Any}()
    #test subs
    for i=1:4
        x = Sym("x$i")
        ex=ex*x
        dict2[x] = i
        dict1[string(x)] = i
    end
    for d in [dict1, dict2]
        @test ex |> subs(d) == factorial(4)
        @test subs(ex, d) == factorial(4)
        @test subs(ex, d...) == factorial(4)
        @test ex |> subs(d...) == factorial(4)
        @test ex(d) == factorial(4)
        @test ex(d...) == factorial(4)
    end

    a = Sym("a")
    b = Sym("b")
    line = x -> a + b * x
    sol = solve([line(0)-1, line(1)-2],[a,b])
    ex = line(10)
    @test ex |> subs(sol) == 11
    @test ex(sol) == ex(sol...) == 11

    ## Conversion
    x = Sym("x")
    p = subs(x,x,pi)
    q = subs(x,x,1//2)
    r = subs(x,x,1.2)
    z = subs(x,x,1)
    @test isa(N(p), Float64)
    @test isa(N(p, 60), BigFloat)
    @test isa(evalf(p), Sym)
    @test isa(N(x), Sym)
    @test isa(N(q), Rational)
    @test isa(N(r), Float64)
    @test isa(N(z), Integer)

    ## method calls via getindex
    p = (x-1)*(x-2)
    @test p[:roots]() == Dict{Any,Any}(Sym(1) => 1, Sym(2)=> 1) # sympy.roots
    p = Poly(p, x)
    @test p[:coeffs]() == Any[1,-3,2] # p.coeffs

    ## algebra
    @test expand((x + 1)*(x + 2)) == x^2 + 3x + 2
    x1 = (x + 1)*(x + 2)
    @test expand(x1) == x^2 + 3x + 2
    @test expand_trig(sin(2x)) == 2sin(x)*cos(x)

    ## math functions
    u = abs(x^2 - 2)
    @test u(x=>0) == 2
    u = min(x, x^2, x^3, x^4)
    @test u(x=>2) == 2
    @test u(x=>1//2) == 1//2^4

    ## solve
    x,y,a = symbols("x,y,a", real=true)
    solve(x^2 - 2x)
    solve(x^2 - 2a, x)
    solve(x^2 - 2a, a)
    solve(Lt(x-2, 0))
    solve( x-2 ≪ 0)
    exs = [x-y-1, x+y-2]
    di = solve(exs)
    @test di[x] == 3//2
    @test map(ex -> subs(ex, di), exs) == [0,0]
    solve([x-y-a, x+y], [x,y])

    ## linsolve
    M=Sym[1 2 3; 2 3 4]
    as = linsolve(M, x, y)
    @test length(elements(as)) == 1
    @vars a b; eqs = (a*x+2y-3, 2b*x + 3y - 4)
    as = linsolve(eqs, x, y)
    @test length(elements(as)) == 1

    ## limits
    @test limit(x -> sin(x)/x, 0) == 1
    @test limit(sin(x)/x, x, 0) |> float == 1
    @test limit(sin(x)/x, x => 0) == 1
    (x, h) = @syms x h
    out = limit((sin(x+h) - sin(x))/h, h, 0)
    @test (out |> replace(x, pi) |> float) == -1.0


    ## diff
    diff(sin(x), x)
    out = diff(sin(x), x, 2)
    @test abs((out |> replace(x, pi/4) |> float) - - sin(pi/4)) < sqrt(eps())

    # partial derivatives
    @syms x y
    @test diff(x^2 + x*y^2, x, 1) == 2x + y^2

    t = symbols("t", real=true)     # vector-valued functions
    r1(t) = [sin(t), cos(t), t]
    u = r1(t)
    kappa = norm(diff(u) × diff(u,t,2)) / norm(diff(u))^3 |> simplify
    @test convert(Rational,kappa) == 1//2

    u = SymFunction("u")
    eqn = Eq(x^2 + u(x)^2, x^3 - u(x))
    @test diff(eqn, x) == Eq(2x + 2u(x) * diff(u(x),x), 3x^2 - diff(u(x),x))

    ## integrate
    @test integrate(sin(x)) == -cos(x)
    @test integrate(sin(x), (x, 0, pi)) == 2.0
    a, b, t = symbols("a, b, t")
    @test integrate(sin(x), (x, a, b)) == cos(a) - cos(b)
    @test integrate(sin(x), (x, a, b)) |> replace(a, 0) |> replace(b, pi) == 2.0
    @test integrate(sin(x) * DiracDelta(x)) == sin(Sym(0))
    @test integrate(Heaviside(x), (x, -1, 1)) == 1
    curv = Curve([exp(t)-1, exp(t)+1], (t, 0, log(Sym(2))))
    @test line_integrate(x + y, curv, [x,y]) == 3 * sqrt(Sym(2))


    ## summation
    summation(1/x^2, (x, 1, 10))
    out = summation(1/x^2, (x, 1, 10))
    out1 = sum([1//x^2 for  x in 1:10])
    @test round(Integer, out.x[:p]) == out1.num
    @test round(Integer, out.x[:q]) == out1.den


    ## Ops
    s = 3
    x = Sym("x")
    v = [x, 1]
    rv = [x 1]
    a = [x 1; 1 x]
    b = [x 1 2; 1 2 x]

    DIMERROR =  DimensionMismatch
    DimensionOrMethodError =  Union{MethodError, DimensionMismatch}
    ## scalar, [vector, matrix]
    @test s .+ v == [x+3, 4]
    @test v .+ s == [x+3, 4]
    @test s .+ rv == [x+3 4]
    @test rv .+ s == [x+3 4]
    @test s .+ a == [x+3 4; 4 x+3]
    @test a .+ s == [x+3 4; 4 x+3]

    @test s .- v == [3-x, 2]
    @test v .- s == [x-3, -2]
    @test s .- rv == [3-x 2]
    @test rv .- s == [x-3 -2]
    @test s .- a == [3-x 2; 2 3-x]
    @test a .- s == [x-3 -2; -2 x-3]

    2v
    2rv
    2a
    s .* v
    v .* s
    s .* rv
    rv .* s
    s .* a
    a .* s

    ## s / v  ## broadcasts s Depreacated
    @test s ./ v == [3/x, 3]
    @test v / s == [x/3, Sym(1)/3]
    @test v .\ s == s ./ v
    @test s \ v == v / s
    ## s / rv ## broadcasts s Deprecated
    @test s ./ rv == [3/x 3]
    @test rv / s == [x/3 Sym(1)/3]
    @test rv .\ s == s ./ rv
    @test s \ rv == rv / s
    ## s / a ## broadcasts s Deprecated
    @test s ./ a == [3/x 3; 3 3/x]
    @test a / s == [x/3 Sym(1)/3; Sym(1)/3 x/3]
    @test a .\ s == s ./ a
    @test s \ a == a / s

    @test_throws MethodError  s ^ v ## error
    @test s .^ v == [3^x, 3]
    @test_throws DimensionOrMethodError v ^ s ## error
    v .^ s
    @test_throws MethodError  s ^ rv ## error
    s .^ rv
    @test_throws DimensionMismatch  rv ^ s ## error
    rv .^ s
    @test_throws MethodError  s ^ a ## error
    s .^ a
    a ^ s
    a .^ s


    ## vector vector
    @test v .+ v == 2v
    ##@test_throws MethodError  v .+ rv ##  no longer an error, broadcase
    @test v .- v == [0, 0]
    @test_throws DIMERROR  v - rv
    @test_throws DimensionOrMethodError   v * v ## error
    @test v .* v == [x^2,1]
    @test dot(v, v) == 1 + conj(x)*x
    v * rv
    rv * v ## 1x2 2 x 1 == 1x1
    v .* rv ## XXX ?? should be what? -- not 2 x 2
    rv .* v ## XXX ditto
    ## @test_throws MethodError  v / v ## error
    v ./ v ## ones()
    v .\ v
    ## @test_throws MethodError  v / rv ## error
    v ./ rv  ## ??
    rv .\ v
    @test_throws MethodError  v ^ v ## error
    v .^ v
    @test_throws MethodError  v ^ rv ## error
    v .^ rv ## ??


    ## vector matrix
    @test_throws DIMERROR v + a ## error (Broadcast?)
    @test_throws DIMERROR a + v ## error
    v .+ a ## broadcasts
    a .+ v
    @test_throws DIMERROR  v - a ## error
    v .- a
    @test_throws DimensionMismatch  v * a ## error
    v .* a
    #@test_throws MethodError  v / a ## error
    v ./ a
    a .\ v
    @test_throws MethodError  v ^ a ## error
    v .^ a
    v
    ## matrix matrix
    a + a
    @test_throws DIMERROR  a + b ## error
    a + 2a
    a - a
    @test_throws DIMERROR  a - b ## error
    a * a
    a .* a
    a * b ## 2x2 * 2*3 -- 2x3
    @test_throws DIMERROR  a .* b ## error -- wrong size
    #@test_throws MethodError  a / a
    a ./ a ## ones
    a .\ a
    ##@test_throws MethodError  a / b ## error
    @test_throws DIMERROR  a ./ b ## error
    @test_throws DIMERROR  b .\ a ## error
    @test_throws MethodError  a ^ a ## error
    a .^ a
    @test_throws MethodError  a ^ b ## error
    @test_throws DIMERROR  a .^ b ## error


    ## Number theory
    #@test isprime(100) == isprime(Sym(100))
    #@test factorint(Sym(100)) == factor(100)
    @test prime(Sym(100)) == 541
    @test multiplicity(Sym(10), 100) == 2


    ## polynomials
    @syms x y
    f1 = 5x^2  + 10x + 3
    g1 = 2x + 2
    q,r = polydiv(f1,g1, domain="QQ") # not div, as can't disambiguate div(Sym(7), 5)) to do integer division
    @test r == Sym(-2)
    @test simplify(q*g1 + r - f1) == Sym(0)
    @test interpolate([1,2,4], x) == interpolate([1,2,3], [1,2,4], x)
    @test interpolate([-1,0,1], [0,1,0], x) == 1 - x^2

    ## piecewise
    x = Sym("x")
    p = piecewise((x, Ge(x,0)), (0, Lt(x,0)), (1, Eq(x,0)))
    ## using infix \ll<tab>, \gt<tab>, \Equal<tab>
    p = piecewise((x, (x ≫ 0)), (0, x ≪ 0), (1, x ⩵ 0))
    @test subs(p,x,2) == 2
    @test subs(p,x,-1) == 0
    @test subs(p,x,0) == 1

    u = ifelse(Lt(x, 0), "neg", ifelse(Gt(x, 0), "pos", "zero"))
    @test subs(u,x,-1) == Sym("neg")
    @test subs(u,x, 0) == Sym("zero")
    @test subs(u,x, 1) == Sym("pos")

    p = piecewise((-x, x ≪ 0), (x, x ≧ 0))


    ## relations
    x,y=symbols("x, y")
    ex = Eq(x^2, x)
    @test lhs(ex) == x^2
    @test rhs(ex) == x
    @test args(ex) == (x^2, x)

    ## mpmath functions
#    if @isdefined mpmath
    if isdefined(SymPy, :mpmath)
        x = Sym("x")
        Sym(big(2))
        Sym(big(2.0))                   # may need mpmath (e.g., conda install mpmath)

        @test limit(besselj(1,1/x), x, 0) == Sym(0)
        complex(N(hankel2(2, pi)))
        bei(2, 3.5)
        bei(1+im, 2+3im)
    end

    ## Assumptions
    @test ask(Q.even(Sym(2))) == true
    @test ask(Q.even(Sym(3))) == false
    @test ask(Q.nonzero(Sym(3))) == true
    @vars x_real real=true
    @vars x_real_positive real=true positive=true
    @test ask(Q.positive(x_real)) == nothing
    @test ask(Q.positive(x_real_positive)) == true
    @test ask(Q.nonnegative(x_real^2)) == true
    @test ask(Q.upper_triangular([x_real 1; 0 x_real])) == true
    @test ask(Q.positive_definite([x_real 1; 1 x_real])) == nothing


              ## sets
    s = FiniteSet("H","T")
    s1 = powerset(s)
    VERSION >= v"0.4.0" && @test length(collect(convert(Set, s1))) == length(collect(s1.x))
    a, b = Interval(0,1), Interval(2,3)
    @test is_disjoint(a, b) == true
    @test measure(union(a, b)) == 2



    ## test cse output
    @test cse(x) == (Any[], x)
    @test cse([x]) == (Any[], [x])
    @test cse([x, x]) == (Any[], [x, x])
    @test cse([x x; x x]) == (Any[], [x x; x x])

## sympy"..."(...)
@vars x
@test sympy"sin"(1) == sin(Sym(1))
@test sympy"removeO"(series(sin(x))) == removeO(series(sin(x)))
@test sympy"rref"([x 1; 1 x])[1] == rref([x 1; 1 x])[1]

end

@testset "Fix past issues" begin
    @vars x y z
    ## Issue # 56
    @test Sym(1+2im) == 1+2IM


    ## Issue #59
    cse(sin(x)+sin(x)*cos(x))
    cse([sin(x), sin(x)*cos(x)])
    cse([sin(x), sin(x)*cos(x), cos(x), sin(x)*cos(x)])

    ## Issue #60, lambidfy
    x, y = symbols("x, y")
    lambdify(sin(x)*cos(2x) * exp(x^2/2))
    fn = lambdify(sin(x)*asin(x)*sinh(x)); fn(0.25)
    lambdify(real(x)*imag(x))
    #    @test lambdify(Min(x,y))(3,2) == 2

    ex = 2 * x^2/(3-x)*exp(x)*sin(x)*sind(x)
    fn = lambdify(ex); map(fn, rand(10))
    ex = x - y
    #@test lambdify(ex)(3,2) == 1

    i = Indicator(x, 0, 1)
    u = lambdify(i)
    @test u(.5) == 1
    @test u(1.5) == 0

    i2 = SymPy.lambdify_expr(x^2,name=:square)
    @test i2.head == :function
    @test i2.args[1].args[1] == :square
    @test i2.args[2] == :(x.^2)


    ## issue #67
    @test N(Sym(4//3)) == 4//3

    ## issue #71
    @test log(Sym(3), Sym(4)) == log(Sym(4)) / log(Sym(3))

    ## issue #103 # this does not work for `x` (which has `classname(x) == "Symbol"`), but should work for other expressions
    for ex in (sin(x), x*y^2*x, sqrt(x^2 - 2y))
        @test func(ex)(args(ex)...) == ex
    end

    ## properties (Issue #119)
    @test is_odd(Sym(3)) == true
    @test is_monic(Poly(x^2 -2, x)) == true

    ## test round (Issue #153)
    y = Sym(eps())
    @test round(y, 5) == 0
    @test round(y, 16) != 0

end
