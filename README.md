# TryCatch.jl

This package serves to provide the same error handling try-except semantics than in Python using a Julia macro called `@try`

The macro works by having a code block that ends with `@catch`, `@success` and/or `@finally` annotations. These annotations indicate how the flow of the program should behave in the case of an error.

#### @finally <codeblock>
The @finally annotation provides a way to run a block of code, regardless of how the @try macro exits. Nothing is returned from the @finally code block, i.e. `@try 1 @finally 2` will return `2`

#### @success <codeblock>
The @success annotation provides a way to run a block of code _only_ when the try-code ran without errors. Note that if the @success annotation is provided and reached, then the success block's value will be returned, i.e. `@try 1 @success 2` will return `2`.
           
#### @catch <condition> <codeblock>
The @catch annotation provides a way to run a block of code when a condition is met. You can have multiple catch annotations, each condition will be evaluated from top to bottom, until a condition is met, then only that codeblock will be run. If a condition is met, no error will be thrown, but if no condition is met, the original error will still be thrown. In the case of an caught exception, that catch block's value will be returned, i.e. `@try sqrt("0") @except e->true 0` will return `0`.
           
The `<condition>` must be a lambda function of the form `arg->(...)`. For example `@try sqrt("0") @except e->e isa MethodError 0` will catch a MethodError exception. For convenience, we also provide two additional shorthands notations:

  1. `@except foo::MethodError println(foo)` is shorthand for <br> `@except foo->(foo isa MethodError) println(foo)`
  2. `@except (foo isa MethodError || foo isa OtherError) println(foo)` is shorthand for <br> `@except foo->(foo isa MethodError || foo isa OtherError) println(foo)`, with the leftmost symbol `foo` is as the exception value.


### By example
```julia
julia> using TryCatch

julia> @try begin
           1 + 2
           sqrt("34")

           @catch e->e isa MethodError begin
               println("Oops cannot use sqrt on a string: ", e)
           end
           @success begin
               println("This will only execute when no error occurs")
           end
           @finally begin
               println("This will always execute")
           end
       end
Oops cannot use sqrt on a string: MethodError(sqrt, ("34",), 0x00000000000073cc)
This will always execute
```


```julia
julia> @try sqrt("34") @catch e::MethodError println("Oops")
Oops
```

