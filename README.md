# TryExcept

This package serves to provide the same error handling try-except semantics than in Python using a Julia macro.

Basic usage:
```
using TryCatch

@try begin
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
```
