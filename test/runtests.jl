using TryCatch
using Test

@testset "TryCatch.jl" begin
    
   # Write your tests here.
    @test (@try 1 @success 2) == 2


    @test (@try 1) == 1


    @test_throws MethodError (@try sqrt("34"))
    

    @test_throws MethodError (@try sqrt("34") (@catch e::ErrorException e))


    # If we throw, the Exception block is returned
    @test (@try sqrt("34") (@catch e::MethodError 5)) == 5


    # catch MethodError
    @test (
    @try begin
        sqrt("34")
        @catch e isa MethodError begin
            52
        end
    end
    ) == 52


    # catch MethodError
    @test (
    @try begin
        sqrt("34")
        @catch e::MethodError begin
            52
        end
    end
    ) == 52


    # catch by complicated boolean expression
    @test (
    @try begin
        sqrt("34")
        @catch e->contains(string(e), "MethodError") begin
            52
        end
    end
    ) == 52


    # catch by complicated boolean expression
    @test (
    @try begin
        sqrt("34")
        @catch jasgdakja->contains(string(jasgdakja), "MethodError") begin
            52
        end
    end
    ) == 52
        

    # Let's see multiple catch blocks
    @test (
    @try begin
        sqrt("35")

        @catch _->false 15
        @catch _::ErrorException 20
        @catch _::MethodError 25
        @catch _->true 30
    end
    ) == 25


    # Finally annotation
    @test (begin
        a = 5
        @try begin
            @finally a = 6
        end
        a
    end) == 6



    # Finally annotation with catch
    @test (begin
        a = 5
        @try begin
            sqrt("35")

            @catch _::MethodError 25
            @finally a = 6
        end
        a
    end) == 6


    # Finally annotation with success annotation
    @test (begin
        a = nothing
        b = nothing
        @try begin
            sqrt("35")

            @catch _::MethodError 25
            @success b = 9
            @finally a = 6
        end
        b
    end) === nothing


    # Finally annotation with success annotation
    @test (begin
        a = nothing
        b = nothing
        @try begin
            
            @catch _::MethodError 25
            @success b = 9
            @finally a = 6
        end
        b
    end) === 9

end
