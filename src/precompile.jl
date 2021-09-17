if isdefined(Base, :bodyfunction)
    __lookup_kwbody__(m) = Base.bodyfunction(m)
else
    __lookup_kwbody__(m) = missing
end

function _precompile_()
    ccall(:jl_generating_output, Cint, ()) == 1 || return nothing
    # widgets
    ## slider
    precompile(Tuple{typeof(slider),UnitRange{Int}})
    precompile(Tuple{Core.kwftype(typeof(slider)),NamedTuple{(:signal, :orientation),Tuple{Signal{Int},Char}},typeof(slider),UnitRange{Int}})
    precompile(Tuple{typeof(push!),Slider{Int},UnitRange{Int},Int})
    precompile(Tuple{typeof(push!),Slider{Float32},StepRangeLen{Float32,Float64,Float64},Float32})
    precompile(Tuple{typeof(push!),Slider{Float64},StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},Float64})
    precompile(Tuple{Type{Slider},Signal{Int},Gtk.GtkScaleLeaf,UInt,Array{Any,1}})
    precompile(Tuple{Type{Slider},Signal{Float64},GtkScaleLeaf,UInt,Array{Any,1}})
    precompile(Tuple{Type{Slider},Signal{Float32},GtkScaleLeaf,UInt,Array{Any,1}})
    let fbody = __lookup_kwbody__(which(slider, (StepRangeLen{Float32,Float64,Float64},)))
        if !ismissing(fbody)
            precompile(fbody, (Nothing,Nothing,Signal{Float32},String,Bool,Nothing,typeof(slider),StepRangeLen{Float32,Float64,Float64},))
            precompile(fbody, (Nothing,Nothing,Signal{Float64},String,Bool,Nothing,typeof(slider),StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}},))
        end
    end
    ## checkbox
    precompile(Tuple{typeof(checkbox)})
    precompile(Tuple{typeof(checkbox),Bool})
    precompile(Tuple{Core.kwftype(typeof(checkbox)),NamedTuple{(:label,),Tuple{String}},typeof(checkbox)})
    precompile(Tuple{typeof(push!),Checkbox,Bool})
    ## togglebutton
    precompile(Tuple{typeof(togglebutton)})
    precompile(Tuple{typeof(togglebutton),Bool})
    precompile(Tuple{Core.kwftype(typeof(togglebutton)),NamedTuple{(:label,),Tuple{String}},typeof(togglebutton)})
    ## button
    precompile(Tuple{typeof(button)})
    precompile(Tuple{typeof(button),String})
    precompile(Tuple{Core.kwftype(typeof(button)),NamedTuple{(:widget,),Tuple{Gtk.GtkToolButtonLeaf}},typeof(button)})
    precompile(Tuple{Core.kwftype(typeof(button)),NamedTuple{(:widget,),Tuple{Gtk.GtkButtonLeaf}},typeof(button)})
    ## spinbutton
    precompile(Tuple{typeof(spinbutton),UnitRange{Int}})
    precompile(Tuple{Type{SpinButton},Signal{Int},Gtk.GtkSpinButtonLeaf,UInt,Array{Any,1}})
    precompile(Tuple{Core.kwftype(typeof(spinbutton)),NamedTuple{(:widget, :signal),Tuple{Gtk.GtkSpinButtonLeaf,Signal{Int}}},typeof(spinbutton),UnitRange{Int}})
    precompile(Tuple{typeof(push!),SpinButton{Int},UnitRange{Int},Int})
    ## cyclicspinbutton
    precompile(Tuple{typeof(cyclicspinbutton),UnitRange{Int},Signal{Bool}})
    precompile(Tuple{Type{CyclicSpinButton},Signal{Int},Gtk.GtkSpinButtonLeaf,UInt,Array{Any,1}})
    ## textbox
    precompile(Tuple{typeof(textbox),String})
    precompile(Tuple{Type{Textbox},Signal{String},Gtk.GtkEntryLeaf,UInt,Array{Any,1},Nothing})
    precompile(Tuple{Type{Textbox},Signal{Int},Gtk.GtkEntryLeaf,UInt,Array{Any,1},UnitRange{Int}})
    precompile(Tuple{Type{Textbox},Signal{Float64},GtkEntryLeaf,UInt,Array{Any,1},Nothing})
    precompile(Tuple{Type{Textbox},Signal{Float32},GtkEntryLeaf,UInt,Array{Any,1},Nothing})
    precompile(Tuple{Core.kwftype(typeof(textbox)),NamedTuple{(:signal,),Tuple{Signal{Int}}},typeof(textbox),Type{Int}})
    precompile(Tuple{Core.kwftype(typeof(textbox)),NamedTuple{(:range,),Tuple{UnitRange{Int}}},typeof(textbox),Int})
    precompile(Tuple{Core.kwftype(typeof(textbox)),NamedTuple{(:widget, :signal, :range),Tuple{GtkEntryLeaf,Signal{Int},Base.OneTo{Int}}},typeof(textbox),Int})
    let fbody = __lookup_kwbody__(which(textbox, (Type{Float32},)))
        if !ismissing(fbody)
            precompile(fbody, (GtkEntryLeaf,Nothing,Nothing,Signal{Float32},Bool,Nothing,Symbol,typeof(textbox),Type{Float32},))
        end
    end
    ## textarea
    precompile(Tuple{typeof(textarea),String})
    ## label
    precompile(Tuple{typeof(label),String})
    ## dropdown
    precompile(Tuple{typeof(dropdown),Array{Pair{String,Function},1}})
    precompile(Tuple{Core.kwftype(typeof(dropdown)),NamedTuple{(:label,),Tuple{String}},typeof(dropdown),Array{Pair{String,Function},1}})
    ## progressbar
    precompile(Tuple{typeof(progressbar),Interval{:closed,:closed,Int}})
    ## player
    precompile(Tuple{typeof(player),UnitRange{Int}})
    precompile(Tuple{typeof(player),Signal{Int},UnitRange{Int}})
    let fbody = __lookup_kwbody__(which(player, (Signal{Int},Base.OneTo{Int},)))
        if !ismissing(fbody)
            precompile(fbody, (String,Int,typeof(player),Signal{Int},Base.OneTo{Int},))
        end
    end
    ## timewidget
    precompile(Tuple{Core.kwftype(typeof(timewidget)),NamedTuple{(:signal,),Tuple{Signal{Time}}},typeof(timewidget),Time})
    precompile(Tuple{typeof(push!),TimeWidget{Time},Time})
    precompile(Tuple{typeof(push!),TimeWidget{DateTime},DateTime})
    ## datetimewidget
    precompile(Tuple{Core.kwftype(typeof(datetimewidget)),NamedTuple{(:signal,),Tuple{Signal{DateTime}}},typeof(datetimewidget),DateTime})

    # canvas
    for unit in (DeviceUnit, UserUnit)
        precompile(Tuple{typeof(canvas),Type{unit}})
        precompile(Tuple{typeof(mousedown_cb),  Ptr{GObject},Ptr{Gtk.GdkEventButton},MouseHandler{unit}})
        precompile(Tuple{typeof(mouseup_cb),    Ptr{GObject},Ptr{Gtk.GdkEventButton},MouseHandler{unit}})
        precompile(Tuple{typeof(mousemove_cb),  Ptr{GObject},Ptr{Gtk.GdkEventScroll},MouseHandler{unit}})
        precompile(Tuple{typeof(mousescroll_cb),Ptr{GObject},Ptr{Gtk.GdkEventScroll},MouseHandler{unit}})
        precompile(Tuple{typeof(init_pan_drag),Canvas{unit},Signal{ZoomRegion{RInt}}})
        precompile(Tuple{typeof(init_zoom_rubberband),Canvas{unit},Signal{ZoomRegion{RInt}}})
        precompile(Tuple{typeof(init_zoom_scroll),Canvas{unit},Signal{ZoomRegion{RInt}}})
        precompile(Tuple{typeof(init_pan_scroll),Canvas{unit},Signal{ZoomRegion{RInt}}})
        precompile(Tuple{typeof(Reactive.run_push),Signal{MouseScroll{unit}},MouseScroll{unit},Function})
        precompile(Tuple{typeof(draw),Function,Canvas{unit},Signal{Int},Vararg{Signal{Int},N} where N})
    end
    precompile(Tuple{Type{ZoomRegion},Tuple{Base.OneTo{Int},Base.OneTo{Int}}})
    precompile(Tuple{typeof(push!),Signal{ZoomRegion{RInt}},Tuple{UnitRange{Int},UnitRange{Int}}})
    # image_surface
    precompile(Tuple{typeof(image_surface),Matrix{RGB{N0f8}}})
    precompile(Tuple{typeof(image_surface),Matrix{RGBA{N0f8}}})
    precompile(Tuple{typeof(image_surface),Matrix{Gray{N0f8}}})
    # map
    # Note: @asserts on some of these cause problems on earlier versions of Julia
    precompile(Tuple{typeof(map),Function,Signal{ZoomRegion{RInt}}})
    precompile(Tuple{typeof(map),Function,Textbox{String},Textbox{Int}})
    precompile(Tuple{typeof(map),Function,Button})
    for unit in (DeviceUnit, UserUnit)
        precompile(Tuple{typeof(map),Function,Signal{MouseButton{unit}}})
        precompile(Tuple{typeof(map),Function,Signal{MouseScroll{unit}}})
    end
    # gc_preserve
    precompile(Tuple{typeof(gc_preserve),GtkWindowLeaf,Tuple{Dict{String,Any},Signal{Nothing},Signal{Nothing}}})
    precompile(Tuple{typeof(gc_preserve),GtkWindowLeaf,Dict{String,Dict{String,Any}}})
    precompile(Tuple{typeof(gc_preserve),GtkFrameLeaf,Player{PlayerWithTextbox}})
    # init_signal2widget
    precompile(Tuple{typeof(init_signal2widget),GtkScaleLeaf,UInt,Signal{Int}})
    precompile(Tuple{typeof(init_signal2widget),GtkScaleLeaf,UInt,Signal{Float64}})
    precompile(Tuple{typeof(init_signal2widget),GtkScaleLeaf,UInt,Signal{Float32}})
end
