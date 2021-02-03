module TryCatch
    export @try


    specials = (:(var"@catch"), :(var"@else"), :(var"@finally"))

    "
    Test if an expression is one of the special annotations
    "
    isspecial(ex) = begin
        if ex isa Expr && ex.head == :macrocall && ex.args[1] ∈ specials
            true
        else
            false
        end
    end


    "
    Copy an expression-like object
    "
    copyex(ex::Expr) = copy(ex)
    copyex(ex) = ex


    "
    Truncated one-line string representation of an expression
    "
    strexpr(ex, truncate=nothing) = begin
        exstr = string(linenumberremove(ex))
        exstr = join(strip.(split(exstr, "\n")), " ")
        if truncate !== nothing && lastindex(exstr) > truncate-3
            exstr = join([i for i in exstr][begin:truncate])*"..."
        end
        return exstr
    end


    "
    Given `@try 3 @catch e @else 21 @finally 1` unnest the inner catch/else/finally macros from the outer ones
    in order to flatten the structure.
    "
    unnestmacrolabels(exs) = begin
        exs = [copyex(i) for i in exs]
        
        i=0; while (i+=1)<=length(exs)
            if isspecial(exs[i])
               for j ∈ 2:length(exs[i].args)
                    if isspecial(exs[i].args[j])
                        # append the rest of the lines to underneath this macro
                        exs[i].args, leftovers = exs[i].args[1:j-1], exs[i].args[j:end]
                        for k ∈ 1:length(leftovers)
                            insert!(exs, i+k, leftovers[k])
                        end

                        # pre-advance i a few lines 
                        i+=length(leftovers)-1
                    end
                end
            end
        end

        return exs
    end


    "
    Given lines of code, split them into groups: :head, @catch, @else and @finally
    "
    split_try_labels_into_groups(exs) = begin

        groups = [:head, specials...]
        d = Dict()

        for g in groups
            d[g] = []
        end

        gᵢ = 1
        macroname = :(var"@try")
        seen = Set([:head])
        for i ∈ 1:length(exs)
            ex = exs[i]
            
            if ex isa Expr && ex.head == :macrocall && ex.args[1] in specials
                macronameᵢ = ex.args[1]
                if macronameᵢ ∈ groups[gᵢ:end]
                    gᵢ = findfirst(x->(macronameᵢ==x), groups)

                    # may have multiple catch blocks
                    if groups[gᵢ] == :(var"@catch")
                        #push!(d[groups[gᵢ]], [])

                        if length(ex.args) >=5 
                            throw(ErrorException("syntax: $(string(groups[gᵢ])) unexpected code block `$(strexpr(ex.args[5], 23))`"))
                        end

                        # linenumber+condition => block
                        if length(ex.args) < 3
                            cond = (ex.args[2], Expr(:->, gensym(:e), true))
                            args = Vector{Any}(ex.args[2:end])
                        else
                            cond = (ex.args[2], ex.args[3])
                            args = Vector{Any}([ex.args[2], ex.args[4:end]...])
                        end

                        # Also push the linenumbernode
                        push!(d[groups[gᵢ]], cond=>args)

                    # may have single other blocks
                    else
                        if macronameᵢ == macroname
                            throw(ErrorException("syntax: unexpected $(macronameᵢ) following $(macroname)"))
                        end

                        if length(ex.args) >=4
                            throw(ErrorException("syntax: $(string(groups[gᵢ])) unexpected code block `$(strexpr(ex.args[4], 23))`"))
                        end

                        # Also push the linenumbernode
                        append!(d[groups[gᵢ]], ex.args[2:end])

                    end
                else
                    throw(ErrorException("syntax: unexpected $(macronameᵢ) following $(macroname)"))
                end

                macroname = macronameᵢ
                push!(seen, macroname)

            else
                if groups[gᵢ] == :(var"@catch")
                    push!(d[groups[gᵢ]][end][2], ex)
                else
                    push!(d[groups[gᵢ]], ex)
                end
            end
        end

        # Don't record unseen macro labels that was never seen
        for key in keys(d)
            if !(key ∈ seen)
                d[key] = nothing
            end
        end

        return d
    end
    

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
        if ex.head == :macrocall
            ex = copyex(ex)
            ex.args[2] = nothing
        end
        Expr((linenumberremove(i) for i ∈ [ex.head; ex.args] if !(i isa LineNumberNode))...)
    end
    linenumberremove(ex::LineNumberNode) = Expr(:block)
    linenumberremove(ex) = ex


    "
    Convert our custom condition-like expression into a proper boolean expression with an entry-symbol
    "
    function conditionhelper(ex, linenumber=nothing)
        if ex isa Expr && ex.head == :->
            larg = ex.args[1]
            if !(larg isa Symbol)
                throw(ErrorException("@catch lambda condition must have a single argument like `e->true`, got `$(strexpr(ex, 23))`"))
            end

            return ex.args[2], larg

        elseif ex isa Expr && ex.head == :(::)
            if !(length(ex.args)==2) || !(ex.args[1] isa Symbol)
                throw(ErrorException("@catch condition must be in the form `e::TypeOfError`, got `$(strexpr(ex, 23))`"))
            end

            return Expr(:block,
                        linenumber, 
                        :($(ex.args[1]) isa $(ex.args[2]))), ex.args[1]

        elseif ex isa Expr
            ex_copy = ex
            while !(ex_copy isa Symbol)
                if !(ex_copy isa Expr)
                    throw(ErrorException("@catch condition must have a symbol at the leftmost location, got `$(strexpr(ex_copy, 23))`"))
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
        # Check correct number of arguments
        if length(exs) >=2 && !isspecial(exs[2])
            throw(ErrorException("syntax: @try unexpected code block `$(strexpr(exs[2], 23))`"))
        end

        # Turn :block entry into a list
        if length(exs) == 1  
            if exs[1] isa Expr && exs[1].head == :block
                exs = exs[1].args
            end
        end

        exs = unnestmacrolabels(exs)
        d = split_try_labels_into_groups(exs)


        # Convert the groups into expressions
        @gensym exception successful successresult
        conditions = []
        if d[Symbol("@catch")] !== nothing
            for ((linenum, cond), block) ∈ d[Symbol("@catch")]
                # refactor into proper conditionals
                cond, sym = conditionhelper(cond, linenum)

                # find-and-repalace error symbol in block
                cond = symbolrename(cond, sym, exception)
                block = symbolrename(block, sym, exception)

                push!(
                    conditions,
                    Expr(:block, linenum, cond) => Expr(:block, block...)
                )
            end
        end

        headₓₓ = Expr(:block, d[:head]...)
        catchₓₓ = ifgenerator(conditions, :(rethrow($exception)))
        elseₓₓ = if d[Symbol("@else")]===nothing 
                     nothing 
                 else 
                     Expr(:(=), successresult, Expr(:if, successful, Expr(:block, d[Symbol("@else")]...)))
                 end

        finallyₓₓ = if d[Symbol("@finally")]===nothing 
                        nothing 
                    else
                        Expr(:block, d[Symbol("@finally")]...)
                    end


        @gensym headₓ elseₓ finallyₓ catchₓ
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
                    $elseₓ
                finally
                    $finallyₓ
                end
            end;
            $successresult
        )

        # Only return `successresults` if @else annotation is present
        if d[Symbol("@else")] === nothing
            template.args = template.args[1:end-1]
        end

        # Strip the Trycatch file lines from this macro
        template = linenumberremove(template)

        replacements = Dict(headₓ=>headₓₓ,
                            catchₓ=>catchₓₓ, 
                            elseₓ=>elseₓₓ, 
                            finallyₓ=>finallyₓₓ)

        # Remove any `nothing` expression
        template = symbolremove(template, [key for (key,val) ∈ replacements if val === nothing])

        # Fill the expression with 
        template = symbolrename(template, replacements)

        esc(template)
    end
end
