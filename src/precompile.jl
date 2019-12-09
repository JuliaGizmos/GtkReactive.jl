const __bodyfunction__ = Dict{Method,Any}()

# Find keyword "body functions" (the function that contains the body
# as written by the developer, called after all missing keyword-arguments
# have been assigned values), in a manner that doesn't depend on
# gensymmed names.
# `mnokw` is the method that gets called when you invoke it without
# supplying any keywords.
function __lookup_kwbody__(mnokw::Method)
    function getsym(arg)
        isa(arg, Symbol) && return arg
        @assert isa(arg, GlobalRef)
        return arg.name
    end

    f = get(__bodyfunction__, mnokw, nothing)
    if f === nothing
        fmod = mnokw.module
        # The lowered code for `mnokw` should look like
        #   %1 = mkw(kwvalues..., #self#, args...)
        #        return %1
        # where `mkw` is the name of the "active" keyword body-function.
        ast = Base.uncompressed_ast(mnokw)
        if isa(ast, Core.CodeInfo) && length(ast.code) >= 2
            callexpr = ast.code[end-1]
            if isa(callexpr, Expr) && callexpr.head == :call
                fsym = callexpr.args[1]
                if isa(fsym, Symbol)
                    f = getfield(fmod, fsym)
                elseif isa(fsym, GlobalRef)
                    if fsym.mod === Core && fsym.name === :_apply
                        f = getfield(mnokw.module, getsym(callexpr.args[2]))
                    elseif fsym.mod === Core && fsym.name === :_apply_iterate
                        f = getfield(mnokw.module, getsym(callexpr.args[3]))
                    else
                        f = getfield(fsym.mod, fsym.name)
                    end
                else
                    f = missing
                end
            else
                f = missing
            end
        else
            f = missing
        end
        __bodyfunction__[mnokw] = f
    end
    return f
end

function _precompile_()
    ccall(:jl_generating_output, Cint, ()) == 1 || return nothing
    # widgets
    ## slider
    @assert precompile(Tuple{typeof(slider),UnitRange{Int}})
    @assert precompile(Tuple{Core.kwftype(typeof(slider)),NamedTuple{(:signal, :orientation),Tuple{Signal{Int},Char}},typeof(slider),UnitRange{Int}})
    @assert precompile(Tuple{typeof(push!),Slider{Int},UnitRange{Int},Int})
    @assert precompile(Tuple{typeof(push!),Slider{Float32},StepRangeLen{Float32,Float64,Float64},Float32})
    @assert precompile(Tuple{typeof(push!),Slider{Float64},StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},Float64})
    @assert precompile(Tuple{Type{Slider},Signal{Int},Gtk.GtkScaleLeaf,UInt,Array{Any,1}})
    @assert precompile(Tuple{Type{Slider},Signal{Float64},GtkScaleLeaf,UInt,Array{Any,1}})
    @assert precompile(Tuple{Type{Slider},Signal{Float32},GtkScaleLeaf,UInt,Array{Any,1}})
    let fbody = try __lookup_kwbody__(which(slider, (StepRangeLen{Float32,Float64,Float64},))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (Nothing,Nothing,Signal{Float32},String,Bool,Nothing,typeof(slider),StepRangeLen{Float32,Float64,Float64},))
            precompile(fbody, (Nothing,Nothing,Signal{Float64},String,Bool,Nothing,typeof(slider),StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},))
        end
    end
    ## checkbox
    @assert precompile(Tuple{typeof(checkbox)})
    @assert precompile(Tuple{typeof(checkbox),Bool})
    @assert precompile(Tuple{Core.kwftype(typeof(checkbox)),NamedTuple{(:label,),Tuple{String}},typeof(checkbox)})
    @assert precompile(Tuple{typeof(push!),Checkbox,Bool})
    ## togglebutton
    @assert precompile(Tuple{typeof(togglebutton)})
    @assert precompile(Tuple{typeof(togglebutton),Bool})
    @assert precompile(Tuple{Core.kwftype(typeof(togglebutton)),NamedTuple{(:label,),Tuple{String}},typeof(togglebutton)})
    ## button
    @assert precompile(Tuple{typeof(button)})
    @assert precompile(Tuple{typeof(button),String})
    @assert precompile(Tuple{Core.kwftype(typeof(button)),NamedTuple{(:widget,),Tuple{Gtk.GtkToolButtonLeaf}},typeof(button)})
    @assert precompile(Tuple{Core.kwftype(typeof(button)),NamedTuple{(:widget,),Tuple{Gtk.GtkButtonLeaf}},typeof(button)})
    ## spinbutton
    @assert precompile(Tuple{typeof(spinbutton),UnitRange{Int}})
    @assert precompile(Tuple{Type{SpinButton},Signal{Int},Gtk.GtkSpinButtonLeaf,UInt,Array{Any,1}})
    @assert precompile(Tuple{Core.kwftype(typeof(spinbutton)),NamedTuple{(:widget, :signal),Tuple{Gtk.GtkSpinButtonLeaf,Signal{Int}}},typeof(spinbutton),UnitRange{Int}})
    @assert precompile(Tuple{typeof(push!),SpinButton{Int},UnitRange{Int},Int})
    ## cyclicspinbutton
    @assert precompile(Tuple{typeof(cyclicspinbutton),UnitRange{Int},Signal{Bool}})
    @assert precompile(Tuple{Type{CyclicSpinButton},Signal{Int},Gtk.GtkSpinButtonLeaf,UInt,Array{Any,1}})
    ## textbox
    @assert precompile(Tuple{typeof(textbox),String})
    @assert precompile(Tuple{Type{Textbox},Signal{String},Gtk.GtkEntryLeaf,UInt,Array{Any,1},Nothing})
    @assert precompile(Tuple{Type{Textbox},Signal{Int},Gtk.GtkEntryLeaf,UInt,Array{Any,1},UnitRange{Int}})
    @assert precompile(Tuple{Type{Textbox},Signal{Float64},GtkEntryLeaf,UInt,Array{Any,1},Nothing})
    @assert precompile(Tuple{Type{Textbox},Signal{Float32},GtkEntryLeaf,UInt,Array{Any,1},Nothing})
    @assert precompile(Tuple{Core.kwftype(typeof(textbox)),NamedTuple{(:signal,),Tuple{Signal{Int}}},typeof(textbox),Type{Int}})
    @assert precompile(Tuple{Core.kwftype(typeof(textbox)),NamedTuple{(:range,),Tuple{UnitRange{Int}}},typeof(textbox),Int})
    @assert precompile(Tuple{Core.kwftype(typeof(textbox)),NamedTuple{(:widget, :signal, :range),Tuple{GtkEntryLeaf,Signal{Int},Base.OneTo{Int}}},typeof(textbox),Int})
    let fbody = try __lookup_kwbody__(which(textbox, (Type{Float32},))) catch missing end
        if !ismissing(fbody)
            precompile(fbody, (GtkEntryLeaf,Nothing,Nothing,Signal{Float32},Bool,Nothing,Symbol,typeof(textbox),Type{Float32},))
        end
    end
    ## textarea
    @assert precompile(Tuple{typeof(textarea),String})
    ## label
    @assert precompile(Tuple{typeof(label),String})
    ## dropdown
    @assert precompile(Tuple{typeof(dropdown),Array{Pair{String,Function},1}})
    @assert precompile(Tuple{Core.kwftype(typeof(dropdown)),NamedTuple{(:label,),Tuple{String}},typeof(dropdown),Array{Pair{String,Function},1}})
    ## progressbar
    @assert precompile(Tuple{typeof(progressbar),Interval{:closed,:closed,Int}})
    ## player
    @assert precompile(Tuple{typeof(player),UnitRange{Int}})
    @assert precompile(Tuple{typeof(player),Signal{Int},UnitRange{Int}})
    let fbody = try __lookup_kwbody__(which(player, (Signal{Int},Base.OneTo{Int},))) catch missing end
        if !ismissing(fbody)
            @assert precompile(fbody, (String,Int,typeof(player),Signal{Int},Base.OneTo{Int},))
        end
    end
    ## timewidget
    @assert precompile(Tuple{Core.kwftype(typeof(timewidget)),NamedTuple{(:signal,),Tuple{Signal{Time}}},typeof(timewidget),Time})
    @assert precompile(Tuple{typeof(push!),TimeWidget{Time},Time})
    @assert precompile(Tuple{typeof(push!),TimeWidget{DateTime},DateTime})
    ## datetimewidget
    @assert precompile(Tuple{Core.kwftype(typeof(datetimewidget)),NamedTuple{(:signal,),Tuple{Signal{DateTime}}},typeof(datetimewidget),DateTime})

    # canvas
    for unit in (DeviceUnit, UserUnit)
        @assert precompile(Tuple{typeof(canvas),Type{unit}})
        @assert precompile(Tuple{typeof(mousedown_cb),  Ptr{GObject},Ptr{Gtk.GdkEventButton},MouseHandler{unit}})
        @assert precompile(Tuple{typeof(mouseup_cb),    Ptr{GObject},Ptr{Gtk.GdkEventButton},MouseHandler{unit}})
        @assert precompile(Tuple{typeof(mousemove_cb),  Ptr{GObject},Ptr{Gtk.GdkEventScroll},MouseHandler{unit}})
        @assert precompile(Tuple{typeof(mousescroll_cb),Ptr{GObject},Ptr{Gtk.GdkEventScroll},MouseHandler{unit}})
        @assert precompile(Tuple{typeof(init_pan_drag),Canvas{unit},Signal{ZoomRegion{RInt}}})
        @assert precompile(Tuple{typeof(init_zoom_rubberband),Canvas{unit},Signal{ZoomRegion{RInt}}})
        @assert precompile(Tuple{typeof(init_zoom_scroll),Canvas{unit},Signal{ZoomRegion{RInt}}})
        @assert precompile(Tuple{typeof(init_pan_scroll),Canvas{unit},Signal{ZoomRegion{RInt}}})
        @assert precompile(Tuple{typeof(Reactive.run_push),Signal{MouseScroll{unit}},MouseScroll{unit},Function})
        @assert precompile(Tuple{typeof(draw),Function,Canvas{unit},Signal{Int},Vararg{Signal{Int},N} where N})
    end
    precompile(Tuple{Type{ZoomRegion},Tuple{Base.OneTo{Int},Base.OneTo{Int}}})
    precompile(Tuple{typeof(push!),Signal{ZoomRegion{RInt}},Tuple{UnitRange{Int},UnitRange{Int}}})
    # image_surface
    @assert precompile(Tuple{typeof(image_surface),Matrix{RGB{N0f8}}})
    @assert precompile(Tuple{typeof(image_surface),Matrix{RGBA{N0f8}}})
    @assert precompile(Tuple{typeof(image_surface),Matrix{Gray{N0f8}}})
    # map
    # Note: @asserts on some of these cause problems on earlier versions of Julia
    precompile(Tuple{typeof(map),Function,Signal{ZoomRegion{RInt}}})
    @assert precompile(Tuple{typeof(map),Function,Textbox{String},Textbox{Int}})
    precompile(Tuple{typeof(map),Function,Button})
    for unit in (DeviceUnit, UserUnit)
        precompile(Tuple{typeof(map),Function,Signal{MouseButton{unit}}})
        precompile(Tuple{typeof(map),Function,Signal{MouseScroll{unit}}})
    end
    # gc_preserve
    @assert precompile(Tuple{typeof(gc_preserve),GtkWindowLeaf,Tuple{Dict{String,Any},Signal{Nothing},Signal{Nothing}}})
    @assert precompile(Tuple{typeof(gc_preserve),GtkWindowLeaf,Dict{String,Dict{String,Any}}})
    @assert precompile(Tuple{typeof(gc_preserve),GtkFrameLeaf,Player{PlayerWithTextbox}})
    # init_signal2widget
    @assert precompile(Tuple{typeof(init_signal2widget),GtkScaleLeaf,UInt,Signal{Int}})
    @assert precompile(Tuple{typeof(init_signal2widget),GtkScaleLeaf,UInt,Signal{Float64}})
    @assert precompile(Tuple{typeof(init_signal2widget),GtkScaleLeaf,UInt,Signal{Float32}})

    # anonymous functions
    # (many of these won't work, but worth a shot)
    isdefined(GtkReactive, Symbol("#104#113")) && precompile(Tuple{getfield(GtkReactive, Symbol("#104#113")),Int})
    isdefined(GtkReactive, Symbol("#126#144")) && precompile(Tuple{getfield(GtkReactive, Symbol("#126#144")),Int})
    isdefined(GtkReactive, Symbol("#106#115")) && precompile(Tuple{getfield(GtkReactive, Symbol("#106#115")),Int})
    isdefined(GtkReactive, Symbol("#108#117")) && precompile(Tuple{getfield(GtkReactive, Symbol("#108#117")),Int})
    isdefined(GtkReactive, Symbol("#132#150")) && precompile(Tuple{getfield(GtkReactive, Symbol("#132#150")),Int})
    isdefined(GtkReactive, Symbol("#136#154")) && precompile(Tuple{getfield(GtkReactive, Symbol("#136#154")),Int})
    isdefined(GtkReactive, Symbol("#130#148")) && precompile(Tuple{getfield(GtkReactive, Symbol("#130#148")),Int})
    isdefined(GtkReactive, Symbol("#134#152")) && precompile(Tuple{getfield(GtkReactive, Symbol("#134#152")),Int})
    isdefined(GtkReactive, Symbol("#128#146")) && precompile(Tuple{getfield(GtkReactive, Symbol("#128#146")),Int})
    isdefined(GtkReactive, Symbol("#159#161")) && precompile(Tuple{getfield(GtkReactive, Symbol("#159#161")),Gtk.GtkCanvas})
end
