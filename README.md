# TryCatch.jl

This package provides a Julia macro `@try` in order to provide similar error handling semantics as Python.

The macro works by adding `@catch`, `@else` and/or `@finally` annotations to a code block in order to redirect the error flow of the block.

#### @try
The @try macro is the main utility in this package. It works by annotating a code block with error redirections, in order to control the error flow of the block. E.g.

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

Note that the catch blocks have an effect on the return value: if an error is caught the @try macro will return the affiliated catch block's return value. E.g. `@try sqrt("0") @except _ 0` will return `0`.
           
The query `<condition>` must be a lambda function returning a boolean. For example `@except e->(e isa MethodError)` is a query that will be triggered in the case of a MethodError. For convenience, we provide two additional shorthand notations that can be used as `<condition>`:

  1. `@except foo::MethodError` is shorthand for <br> `@except foo->(foo isa MethodError)`
  2. `@except (foo isa MethodError || foo isa OtherError && <etc>)` is shorthand for <br> `@except foo->(foo isa MethodError || foo isa OtherError && <etc>)`, with the leftmost symbol `foo` taken as the exception. The expection is usually named `e` by convention, but as you can see, this is not a restriction.

#### @else \<codeblock\>
The @else annotation provides a way to run a block of code _only_ when the try-code ran without errors. Note that @else has an effect on the return value: if @else is reached then the @try macro will return the else block's return value. E.g. `@try 1 @success 2` will return `2`.

#### @finally \<codeblock\>
The @finally annotation provides a way to forcefully run a final block of code, regardless of any error encounters. The @finally code block does not partake in the value returning semantics, so something like `@try 1 @finally 2` will still return `1`.

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

