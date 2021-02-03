# TryCatch.jl

This package provides a Julia macro `@try` in order to provide similar error handling semantics as Python.

The macro works by adding `@catch`, `@else` and/or `@finally` annotations to a code block in order to redirect the error flow of the block.

#### @try
The @try macro is the main utility in this package. It works on a code block with error redirection annotations in order to redirect the error flow of the block. i.e.

```julia
@try begin 
    <codeblock>
@catch <condition> 
    <codeblock>
@catch <condition> 
    <codeblock>
@else 
    <codeblock>
@finally
    <codeblock>
end
```

        
#### @catch \<condition\> \<codeblock\>
The @catch annotation provides a way to run a block of code in the case where an error occured. It does so only when it's given condition is met. The idea is to have multiple catch annotations that get's queried from top to bottom. If one of the conditions is met, then that block will be run and all following blocks will be ignored. If and only if no condition is met, the original error will be rethrown. 

In the case of catching an exception, that catch block's evaluation will be returned, i.e. `@try sqrt("0") @except _ 0` will return `0`.
           
The `<condition>` must be a lambda function that return a boolean. For example, `@except e->(e isa MethodError)` will be queried in the case of a MethodError. For convenience, we provide two additional shorthands notations:

  1. `@except foo::MethodError` is shorthand for <br> `@except foo->(foo isa MethodError)`
  2. `@except (foo isa MethodError || foo isa OtherError && <etc>)` is shorthand for <br> `@except foo->(foo isa MethodError || foo isa OtherError && <etc>)`, with the leftmost symbol `foo` taken as the exception value. Usually the argument is named `e` by convention, but this is not a restriction.

#### @else \<codeblock\>
The @else annotation provides a way to run a block of code _only_ when the try-code ran without errors. Note that if the @else annotation is provided and reached, it's evaluated result will be returned. I.e. `@try 1 @success 2` will return `2`.

#### @finally \<codeblock\>
The @finally annotation provides a way to forcefully run a final block of code, regardless of any error encounters. The @finally code block doesn't partake in value returns, so something like `@try 1 @finally 2` will still return `1`.

### By example
```julia
julia> using TryCatch

julia> @try begin

           1 + 2
           sqrt("34")

       @catch e->e isa MethodError 
           println("Oops cannot use sqrt on a string: ", e)
       @else 
           println("This will only execute when no error occurs")
       @finally 
           println("This will always execute")
       end
Oops cannot use sqrt on a string: MethodError(sqrt, ("34",), 0x00000000000073cc)
This will always execute
```


```julia
julia> @try sqrt("34") @catch e::MethodError println("Oops")
Oops

julia> @try sqrt("34") @catch e::ErrorException println("Oops")
ERROR: MethodError: no method matching sqrt(::String)
Closest candidates are:
  sqrt(::Union{Float32, Float64}) at math.jl:581...
```

