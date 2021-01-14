# `FixArgs.Fix` is a combination of `Call` and `Lambda` below.
# Combining these two into one makes the common case of expressing e.g. `x -> x == 3` concise.
# However, it makes it difficult to express a bunch of expressions in `parse.jl`, as simple as `x -> x`,
# or `(f, x) -> f(x)` (which I think is possible with the split, but should check)
# or distinguish between
# `(x, y) -> f(x, g(y))`
# and
# `(x, y) -> f(x, () -> g(y))`

# In Julia 1.6 there is better printing of type aliases.
# So I think there should just be a type alias with the name e.g. `Fix` for the common case to be concise.
struct TypedExpr{H, A}
    head::H
    args::A
end

_typed(expr::Expr) = TypedExpr(
    _typed(expr.head),
    _typed(expr.args)
)

_typed(args::Vector) = tuple(map(_typed, args)...)
_typed(sym::Symbol) = Val(sym)
_typed(x) = x # catch e.g. functions

struct Args{P, KW}
end

struct Lambda{A, B}
    args::A
    body::B
end

struct Call{F, A}
    f::F
    args::A
end

_Union() = Union{}
_Union(x) = Union{x}
_Union(a, b) = Union{a, b}
_Union(x...) = reduce(_Union, x)

KeywordArgType(kwarg_names...) = _Union(sort(collect(kwarg_names))...)

_typed1(expr::TypedExpr{Val{:->}, Tuple{A, B}}) where {A, B} = Lambda(expr.args[1], _typed1(expr.args[2]))
_typed1(expr::TypedExpr{Val{:call}, X}) where {X} = Call(expr.args[1], expr.args[2:end]) # TODO handle TypedExpr with kwargs
_typed1(x) = x

using MacroTools: striplines, flatten

# other order doesn't work. I suppose `striplines` introduces blocks
# TODO normalize `:(x -> $body)` into  `:((x,) -> $body`)
clean_ex(ex) = flatten(striplines(ex))

ex = clean_ex(:(x -> $(==)(x, 0)))
_typed1(_typed(ex))

const FixNew{ARGS_IN, F, ARGS_CALL} = Lambda{ARGS_IN, Call{F, ARGS_CALL}}

using Test
if VERSION >= v"1.6-"
    # test alias printing
    @test string(typeof(_typed1(_typed(ex)))) == "FixNew{Val{:x}, typeof(==), Tuple{Val{:x}, Int64}}"
end

macro tquote(ex)
    # TODO escape unbound Symbols
    _typed1(_typed(clean_ex(ex)))
end