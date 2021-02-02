# TryExcept

This package serves to provide the same error handling try-except semantics than in Python using a Julia macro.

### By example
```julia
julia> using TryCatch

julia> @try begin
           1 + 2
           sqrt("34")

           @catch e->e isa MethodError begin
               println("Oops cannot use sqrt on a string")
           end
           @success begin
               println("This will only execute when no error occurs")
           end
           @finally begin
               println("This will always execute")
           end
       end
Oops cannot use sqrt on a string
This will always execute
```


```julia
julia> @try sqrt("34") @catch e::MethodError println("Oops")
Oops
```
