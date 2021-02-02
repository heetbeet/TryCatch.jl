module TryCatch
    export @try

    
    "
    Function to generate if-elseif-else statements
    "
    ifgenerator(conds=nothing, else_=nothing) = begin
        if conds === nothing || length(conds) == 0
            return else_
        end

        (x, y) = first(conds)
        orig_expr = Expr(:if, x, y)

        expr = orig_expr
        for (i,(x,y)) in enumerate(conds)
            if i==1 
                continue
            end
            push!(expr.args, Expr(:elseif, x, y))
            expr = expr.args[end]
        end

        if else_ !== nothing
            push!(expr.args, else_)
        end

        return orig_expr
    end


    "
    Rename a symbol within an expression to something else
    "
    symbolrename(ex::Expr, find, replace) = begin
        Expr((symbolrename(i, find, replace) for i in [ex.head; ex.args])...)
    end
    
    symbolrename(ex::Symbol, find, replace) = ex == find ? replace : ex

    symbolrename(ex::Expr, findreplace::Dict) = begin
        Expr((symbolrename(i, findreplace) for i in [ex.head; ex.args])...)
    end

    symbolrename(ex::Symbol, findreplace::Dict) = get(findreplace, ex, ex)

    symbolrename(ex, find, replace=nothing) = ex


    "
    Remove symbol from expression
    "
    symbolremove(ex::Expr, slist) = begin
        Expr((symbolremove(i, slist) for i ∈ [ex.head; ex.args] if !(i ∈ slist))...)
    end
    symbolremove(ex, slist) = ex


    "
    Remove any LineNumberNodes from an expression
    "
    linenumberremove(ex::Expr) = begin
        Expr((linenumberremove(i) for i ∈ [ex.head; ex.args] if !(i isa LineNumberNode))...)
    end
    linenumberremove(ex::LineNumberNode) = Expr(:block)
    linenumberremove(ex) = ex


    "
    Convert our allowable set of conditions into boolean expressions
    "
    function conditionhelper(ex, linenumber=nothing)
        if ex isa Expr && ex.head == :->
            larg = ex.args[1]
            if !(larg isa Symbol)
                throw(ArgumentError("@catch's lambda must be single argument, like e->true"))
            end

            return ex.args[2], larg

        elseif ex isa Expr && ex.head == :(::)
            if !(length(ex.args)==2)
                throw(ArgumentError("@catch's type notation must be in the form e::TypeOfError"))
            end

            return Expr(:block,
                        linenumber, 
                        :($(ex.args[1]) isa $(ex.args[2]))), ex.args[1]

        elseif ex isa Expr
            ex_copy = ex
            while !(ex_copy isa Symbol)
                if !(ex_copy isa Expr)
                    "@catch expressions must have a symbol at the leftmost location."
                end
    
                i₁ = ex_copy.head ∈ (:macrocall, :call, :ref) ? 2 : 1
                ex_copy = ex_copy.args[i₁]
            end

            return Expr(:block, linenumber, ex), ex_copy

        elseif ex isa Symbol
            return true, ex
        end

    end


    "
    The @try macro mimickes and extends how error handling is done in Python.
    "
    macro try_ end

    # Rename  @try_ to @try in order to bypass reserved keyword restriction
    var"@try" = var"@try_"
    typeof(var"@try").name.mt.name = Symbol("@try")
    macro try_(exs...)

        # Turn :block entry into a list
        if length(exs) == 1  
            if exs[1] isa Expr && exs[1].head == :block
                exs = exs[1].args
            end
        end

        # Tese are captured and evaluated
        specials = (:(var"@catch"), :(var"@success"), :(var"@finally"))

        # Split according to try lines and side-effect lines
        border = length(exs)+1
        for (i, ex) in enumerate(exs)
            if ex isa Expr && ex.head == :macrocall && ex.args[1] in specials
                border = i
                break
            end
        end
        #if border === nothing
        #    throw(ArgumentError("@try must end with @catch, @success and/or @finally block."))
        #end

        head = exs[1:border-1]
        tail = exs[border:end]

        # Remove trailing LineNumberNode
        if length(head) > 0 && head[end] isa LineNumberNode
            head = head[1:end-1]
        end

        for i in head
            if i ∈ specials
                throw(ArgumentError("@catch, @success and/or @finally blocks must be at the end of @try macro."))
            end

        end

        # Only use the macros
        tail = [i for i in tail if !(i isa LineNumberNode)]
        for i in tail
            if (i.head != :macrocall) || !(i.args[1] in specials)
                throw(ArgumentError("@catch, @success and/or @finally blocks bust be at the end of @try macro."))
            end
        end


        # Ensure only a single success block
        success = [i for i in tail if i.args[1] == :(var"@success")]
        success = if length(success) == 0 
            nothing 
        elseif length(success) == 1 
            if length(success[1].args) != 3
                throw(ArgumentError("@success must contain single expression block"))
            end
            success[1].args[3]
        else 
            throw(ArgumentError("@try may only have one @success block"))
        end


        # Ensure only a single finally block
        finally_ = [i for i in tail if i.args[1] == :(var"@finally")]
        finally_ = if length(finally_) == 0 
            nothing 
        elseif length(finally_) == 1 
            if length(finally_[1].args) != 3
                throw(ArgumentError("@finally must contain single expression block"))
            end
        finally_[1].args[3]
        else 
            throw(ArgumentError("@try may only have one @finally block"))
        end

        # capture all the catch blocks
        @gensym exception
        catch_ = [i for i in tail if i.args[1] == :(var"@catch")]
        conditions = []
        for i in catch_
            if length(i.args) != 4
                throw(ArgumentError("@catch must have form `@catch <condition> <expression>`"))
            end

            elinenum = i.args[2]
            econd, esym = conditionhelper(i.args[3], elinenum)
            eexpr = i.args[4]
            
            # Replace temp symbol with exception symbol
            econd = symbolrename(econd, esym, exception)
            eexpr = symbolrename(eexpr, esym, exception)

            push!(
                conditions,
                Expr(:block, elinenum, econd) => Expr(:block, elinenum, eexpr)
            )
        end
        catchclauses = ifgenerator(conditions,
                                    :(rethrow($exception)))

        
        @gensym headₓ successₓ finallyₓ catchₓ successresultₓ
        @gensym successful successresult
        template = :(
            $successresult = nothing;
            $successful=true;
            try
                $headₓ
            catch $exception
                $successful=false
                $catchₓ
            finally
                try
                    $successₓ
                finally
                    $finallyₓ
                end
            end;
            $successresult
        )

        # Only return `successresults` if @success annotation is present
        if success === nothing
            template.args = template.args[1:end-1]
        end

        # Strip the Trycatch file lines from this macro
        template = linenumberremove(template)

        # Remove any `nothing` expression
        symbolremove(template, [key for (key,val) ∈ [successₓ=>success,
                                                     finallyₓ=>finally_,
                                                     catchₓ=>catch_] if val === nothing])
        
        # Fill the expression with 
        template = symbolrename(template,
                                Dict(headₓ => Expr(:block, head...),
                                     successₓ => Expr(:(=), successresult, Expr(:if, successful, success)),
                                     finallyₓ => finally_,
                                     catchₓ => catchclauses))

        esc(template)
    end
end
