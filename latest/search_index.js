var documenterSearchIndex = {"docs": [

{
    "location": "index.html#",
    "page": "Introduction",
    "title": "Introduction",
    "category": "page",
    "text": ""
},

{
    "location": "index.html#Introduction-1",
    "page": "Introduction",
    "title": "Introduction",
    "category": "section",
    "text": ""
},

{
    "location": "index.html#Scope-of-this-package-1",
    "page": "Introduction",
    "title": "Scope of this package",
    "category": "section",
    "text": "GtkReactive is a package building on the functionality of Gtk.jl and Reactive.jl. Its main purpose is to simplify the handling of interactions among components of a graphical user interface (GUI).Creating a GUI generally involves some or all of the following:creating the controls\narranging the controls (layout) in one or more windows\nspecifying the interactions among components of the GUI\n(for graphical applications) canvas drawing\n(for graphical applications) canvas interaction (mouse clicks, drags, etc.)GtkReactive is targeted primarily at items 1, 3, and 5. Layout is handled by Gtk.jl, and drawing (with a couple of exceptions) is handled by plotting packages or at a lower level by Cairo.GtkReactive is suitable for:\"quick and dirty\" applications which you might create from the command line\nmore sophisticated GUIs where layout is specified using tools like GladeFor usage with Glade, the Input widgets and Output widgets defined by this package allow you to supply a preexisting widget (which you might load with GtkBuilder) rather than creating one from scratch. Users interested in using GtkReactive with Glade are encouraged to see how the player widget is constructed (see src/extrawidgets.jl).At present, GtkReactive supports only a small subset of the widgets provided by Gtk. It is fairly straightforward to add new ones, and pull requests would be welcome."
},

{
    "location": "index.html#Concepts-1",
    "page": "Introduction",
    "title": "Concepts",
    "category": "section",
    "text": "The central concept of Reactive.jl is the Signal, a type that allows updating with new values that then triggers actions that may update other Signals or execute functions. Your GUI ends up being represented as a \"graph\" of Signals that collectively propagate the state of your GUI. GtkReactive couples Signals to Gtk.jl's widgets. In essence, Reactive.jl allows ordinary Julia objects to become the triggers for callback actions; the primary advantage of using Julia objects, rather than Gtk widgets, as the \"application logic\" triggers is that it simplifies reasoning about the GUI and seems to reduce the number of times ones needs to consult the Gtk documentation.Because these can sometimes be a source of bugs, it's worth emphasizing two crucial features of Reactive.jl Signals:updates to Signals are asynchronous, so values will not propagate until the next time the Reactive message-handler runs\nderived signals are subject to garbage-collection; you should either hold a reference to or preserve any derived signals (for any signals that are associated with updating an on-screen widget, see also GtkReactive.gc_preserve).Please see the Reactive.jl documentation for more information."
},

{
    "location": "controls.html#",
    "page": "A first example: GUI controls",
    "title": "A first example: GUI controls",
    "category": "page",
    "text": ""
},

{
    "location": "controls.html#A-first-example:-GUI-controls-1",
    "page": "A first example: GUI controls",
    "title": "A first example: GUI controls",
    "category": "section",
    "text": "Let's create a slider object:julia> using Gtk.ShortNames, GtkReactive\n\njulia> sl = slider(1:11)\nGtk.GtkScaleLeaf with Signal{Int64}(6, nactions=1)\n\njulia> typeof(sl)\nGtkReactive.Slider{Int64}A GtkReactive.Slider holds two important objects: a Signal (encoding the \"state\" of the widget) and a GtkWidget (which controls the on-screen display). We can extract both of these components:julia> signal(sl)\nSignal{Int64}(6, nactions=1)\n\njulia> typeof(widget(sl))\nGtk.GtkScaleLeaf(If you omitted the typeof, you'd instead see a long display that encodes the settings of the GtkScaleLeaf widget.)At present, this slider is not affiliated with any window. Let's create one and add the slider to the window. We'll put it inside a Box so that we can later add more things to this GUI:julia> win = Window(\"Testing\") |> (bx = Box(:v));  # a window containing a vertical Box for layout\n\njulia> push!(bx, sl);    # put the slider in the box, shorthand for push!(bx, widget(sl));\n\njulia> showall(win);Because of the showall, you should now see a window with your slider in it:(Image: slider1)The value should be 6, set to the median of the range 1:11 that we used to create sl. Now drag the slider all the way to the right, and then see what happened to sl:push!(sl, 11)\nReactive.run_till_now()\nsleep(1)\nReactive.run_till_now()julia> sl\nGtk.GtkScaleLeaf with Signal{Int64}(11, nactions=1)You can see that dragging the slider caused the value of the signal to update. Let's do the converse, and set the value of the slider programmatically:julia> push!(sl, 1)  # shorthand for push!(signal(sl), 1)Now if you check the window, you'll see that the slider is at 1.Realistic GUIs may have many different widgets. Let's add a second way to adjust the value of that signal, by allowing the user to type a value into a textbox:julia> tb = textbox(Int; signal=signal(sl))\nGtk.GtkEntryLeaf with Signal{Int64}(1, nactions=2)\n\njulia> push!(bx, tb);\n\njulia> showall(win);(Image: slider2)Here we created the textbox in a way that shared the signal of sl with the textbox; consequently, the textbox updates when you move the slider, and the slider moves when you enter a new value into the textbox. push!ing a value to signal(sl) updates both."
},

{
    "location": "drawing.html#",
    "page": "A simple drawing program",
    "title": "A simple drawing program",
    "category": "page",
    "text": ""
},

{
    "location": "drawing.html#A-simple-drawing-program-1",
    "page": "A simple drawing program",
    "title": "A simple drawing program",
    "category": "section",
    "text": "Aside from widgets, GtkReactive also adds canvas interactions, specifically handling of mouse clicks and scroll events. We can explore some of these tools by building a simple program for drawing lines.Let's begin by creating a window with a canvas in it:using Gtk.ShortNames, GtkReactive, Graphics, Colors\n\nwin = Window(\"Drawing\")\nc = canvas(UserUnit)       # create a canvas with user-specified coordinates\npush!(win, c)Here we specified UserUnit units for our drawing and mouse-position units; the default is DeviceUnit, a.k.a. pixels.  Here we prefer to specify our own units, which here we'll choose to be (0,0) for the top left and (1,1) for the bottom right. With this choice, if a user resizes the window by dragging its border, our lines will stay in the same relative position.We're going to set this up so that a new line is started when the user clicks with the left mouse button; when the user releases the mouse button, the line is finished and added to a list of previously-drawn lines. Consequently, we need a place to store user data. We'll use Signals, so that our Canvas will be notified when there is new material to draw:const lines = Signal([])   # the list of lines that we'll draw\nconst newline = Signal([]) # the in-progress line (will be added to list above)Now, let's make our application respond to mouse-clicks:const drawing = Signal(false)  # this will become true if we're actively dragging\n\nsigstart = map(c.mouse.buttonpress) do btn\n    if btn.button == 1 && btn.modifiers == 0\n        push!(drawing, true)   # start extending the line\n        push!(newline, [btn.position])\n    end\nendsigstart is also a signal; we won't do anything with it, but we assigned it to a variable to prevent it from being garbage-collected. (We could use GtkReactive.gc_preserve(win, sigstart) if we wanted to keep it alive for at least as long as win is active.)Once the user clicks the button, drawing holds value true; from that point forward, any movement of the mouse extends the line by an additional vertex:const dummybutton = MouseButton{UserUnit}()\nsigextend = map(filterwhen(drawing, dummybutton, c.mouse.motion)) do btn\n    push!(newline, push!(value(newline), btn.position))\nendNotice that we made this conditional on drawing by using filterwhen; dummybutton is just a default value of the same type as c.mouse.motion to provide for filterwhen.Finally, when the user releases the mouse button, we stop drawing, store newline in lines, and prepare for the next line by starting with an empty newline:sigend = map(c.mouse.buttonrelease) do btn\n    if btn.button == 1\n        push!(drawing, false)  # stop extending the line\n        push!(lines, push!(value(lines), value(newline)))\n        push!(newline, [])\n    end\nendAt this point, you could already verify that these interactions work by monitoring lines from the command line by clicking, dragging, and releasing.However, it's much more fun to see it in action. Let's set up a draw method for the canvas, one that gets called (1) whenever the window resizes, or (2) whenever lines or newline update:redraw = draw(c, lines, newline) do cnvs, lns, newl\n    fill!(cnvs, colorant\"white\")   # background is white\n    set_coords(cnvs, BoundingBox(0, 1, 0, 1))  # set coordinates to 0..1 along each axis\n    ctx = getgc(cnvs)\n    for l in lns\n        drawline(ctx, l, colorant\"blue\")  # draw old lines in blue\n    end\n    drawline(ctx, newl, colorant\"red\")    # draw new line in red\nend\n\nfunction drawline(ctx, l, color)\n    isempty(l) && return\n    p = first(l)\n    move_to(ctx, p.x, p.y)\n    set_source(ctx, color)\n    for i = 2:length(l)\n        p = l[i]\n        line_to(ctx, p.x, p.y)\n    end\n    stroke(ctx)\nendA lot of these commands come from Cairo.jl and/or Graphics.jl.Our application is done! (But don't forget to showall(win).) Here's a picture of me in the middle of a very fancy drawing:(Image: drawing)You can play with the completed application in the examples/ folder."
},

{
    "location": "zoom_pan.html#",
    "page": "Zoom and pan",
    "title": "Zoom and pan",
    "category": "page",
    "text": ""
},

{
    "location": "zoom_pan.html#Zoom-and-pan-1",
    "page": "Zoom and pan",
    "title": "Zoom and pan",
    "category": "section",
    "text": "In addition to low-level canvas support, GtkReactive also provides high-level functions to make it easier implement rubber-banding, pan, and zoom functionality.To illustrate these tools, let's first open a window with a drawing canvas:julia> using Gtk.ShortNames, GtkReactive, TestImages\n\njulia> win = Window(\"Image\");\n\njulia> c = canvas(UserUnit);\n\njulia> push!(win, c);As explained in A simple drawing program, the UserUnit specifies that mouse pointer positions will be reported in the units we specify, through a set_coords call below.Now let's load an image to draw into the canvas:julia> image = testimage(\"lighthouse\");For what follows, it may be worth reminding readers that julia arrays are indexed as image[row, column], whereas for graphics we usually think in terms of (x, y). Since x corresponds to column and y corresponds to row, some operations will require that we swap the first and second indices.Zoom and pan interactions all work through a ZoomRegion signal; let's create one for this image:julia> zr = Signal(ZoomRegion(image))\nSignal{GtkReactive.ZoomRegion{RoundingIntegers.RInt64}}(GtkReactive.ZoomRegion{RoundingIntegers.RInt64}(GtkReactive.XY{IntervalSets.ClosedInterval{RoundingIntegers.RInt64}}(1..768,1..512),GtkReactive.XY{IntervalSets.ClosedInterval{RoundingIntegers.RInt64}}(1..768,1..512)), nactions=0)The key thing to note here is that it has been created for the intervals 1..768 (corresponding to the width of the image) and 1..512 (the height of the image). Let's now create a view of the image as a Signal:julia> imgsig = map(zr) do r\n           cv = r.currentview   # extract the currently-selected region\n           view(image, UnitRange{Int}(cv.y), UnitRange{Int}(cv.x))\n       end;imgsig will update any time zr is modified. We then define a draw method for the canvas that paints this selection to the canvas:julia> redraw = draw(c, imgsig, zr) do cnvs, img, r\n           copy!(cnvs, img)\n           set_coords(cnvs, r)  # set the canvas coordinates to the selected region\n       end\nSignal{Void}(nothing, nactions=0)We won't need to do anything further with redraw, but as a reminder: by assigning it to a variable we ensure it won't be garbage-collected (if that happened, the canvas would stop updating when imgsig and/or zr update).Now, let's see our image:julia> showall(win);(Image: image1)We could push! values to zr and see the image update:julia> push!(zr, (100:300, indices(image, 2)))(Image: image2)More useful is to couple zr to mouse actions. Let's turn on both zooming and panning:julia> rb = init_zoom_rubberband(c, zr)\nDict{String,Any} with 5 entries:\n  \"drag\"    => Signal{Void}(nothing, nactions=0)\n  \"init\"    => Signal{Void}(nothing, nactions=0)\n  \"active\"  => Signal{Bool}(false, nactions=0)\n  \"finish\"  => Signal{Void}(nothing, nactions=0)\n  \"enabled\" => Signal{Bool}(true, nactions=0)\n\njulia> pandrag = init_pan_drag(c, zr)\nDict{String,Any} with 5 entries:\n  \"drag\"    => Signal{Void}(nothing, nactions=0)\n  \"init\"    => Signal{Void}(nothing, nactions=0)\n  \"active\"  => Signal{Bool}(false, nactions=0)\n  \"finish\"  => Signal{Void}(nothing, nactions=0)\n  \"enabled\" => Signal{Bool}(true, nactions=0)Now hold down your Ctrl key on your keyboard, click on the image, and drag to select a region of interest. You should see the image zoom in on that region. Then try clicking your mouse (without holding Ctrl) and drag; the image will move around, following your mouse. Double-click on the image while holding down Ctrl to zoom out to full view.The returned dictionaries have a number of signals necessary for internal operations. Perhaps the only important user-level element is enabled; if you push!(rb[\"enabled\"], false) then you can (temporarily) turn off rubber-band initiation.If you have a wheel mouse, you can activate additional interactions with init_zoom_scroll and init_pan_scroll."
},

{
    "location": "reference.html#",
    "page": "Reference",
    "title": "Reference",
    "category": "page",
    "text": ""
},

{
    "location": "reference.html#Reference-1",
    "page": "Reference",
    "title": "Reference",
    "category": "section",
    "text": ""
},

{
    "location": "reference.html#GtkReactive.button",
    "page": "Reference",
    "title": "GtkReactive.button",
    "category": "Function",
    "text": "button(label; widget=nothing, signal=nothing)\nbutton(; label=nothing, widget=nothing, signal=nothing)\n\nCreate a push button with text-label label. Optionally provide:\n\na GtkButton widget (by default, creates a new one)\nthe (Reactive.jl) signal coupled to this button (by default, creates a new signal)\n\n\n\n"
},

{
    "location": "reference.html#GtkReactive.checkbox",
    "page": "Reference",
    "title": "GtkReactive.checkbox",
    "category": "Function",
    "text": "checkbox(value=false; widget=nothing, signal=nothing, label=\"\")\n\nProvide a checkbox with the specified starting (boolean) value. Optionally provide:\n\na GtkCheckButton widget (by default, creates a new one)\nthe (Reactive.jl) signal coupled to this checkbox (by default, creates a new signal)\na display label for this widget\n\n\n\n"
},

{
    "location": "reference.html#GtkReactive.togglebutton",
    "page": "Reference",
    "title": "GtkReactive.togglebutton",
    "category": "Function",
    "text": "togglebutton(value=false; widget=nothing, signal=nothing, label=\"\")\n\nProvide a togglebutton with the specified starting (boolean) value. Optionally provide:\n\na GtkCheckButton widget (by default, creates a new one)\nthe (Reactive.jl) signal coupled to this button (by default, creates a new signal)\na display label for this widget\n\n\n\n"
},

{
    "location": "reference.html#GtkReactive.slider",
    "page": "Reference",
    "title": "GtkReactive.slider",
    "category": "Function",
    "text": "slider(range; widget=nothing, value=nothing, signal=nothing, orientation=\"horizontal\")\n\nCreate a slider widget with the specified range. Optionally provide:\n\nthe GtkScale widget (by default, creates a new one)\nthe starting value (defaults to the median of range)\nthe (Reactive.jl) signal coupled to this slider (by default, creates a new signal)\nthe orientation of the slider.\n\n\n\n"
},

{
    "location": "reference.html#GtkReactive.textbox",
    "page": "Reference",
    "title": "GtkReactive.textbox",
    "category": "Function",
    "text": "textbox(value=\"\"; widget=nothing, signal=nothing, range=nothing, gtksignal=:activate)\ntextbox(T::Type; widget=nothing, signal=nothing, range=nothing, gtksignal=:activate)\n\nCreate a box for entering text. value is the starting value; if you don't want to provide an initial value, you can constrain the type with T. Optionally specify the allowed range (e.g., -10:10) for numeric entries, and/or provide the (Reactive.jl) signal coupled to this text box. Finally, you can specify which Gtk signal (e.g. activate, changed) you'd like the widget to update with.\n\n\n\n"
},

{
    "location": "reference.html#GtkReactive.textarea",
    "page": "Reference",
    "title": "GtkReactive.textarea",
    "category": "Function",
    "text": "textarea(value=\"\"; widget=nothing, signal=nothing)\n\nCreates an extended text-entry area. Optionally provide a GtkTextView widget and/or the (Reactive.jl) signal associated with this widget. The signal updates when you type.\n\n\n\n"
},

{
    "location": "reference.html#GtkReactive.dropdown",
    "page": "Reference",
    "title": "GtkReactive.dropdown",
    "category": "Function",
    "text": "dropdown(choices; widget=nothing, value=first(choices), signal=nothing, label=\"\", with_entry=true, icons, tooltips)\n\nCreate a \"dropdown\" widget. choices can be a vector (or other iterable) of options. Optionally specify\n\nthe GtkComboBoxText widget (by default, creates a new one)\nthe starting value\nthe (Reactive.jl) signal coupled to this slider (by default, creates a new signal)\nwhether the widget should allow text entry\n\nExamples\n\na = dropdown([\"one\", \"two\", \"three\"])\n\nTo link a callback to the dropdown, use\n\nf = dropdown((\"turn red\"=>colorize_red, \"turn green\"=>colorize_green))\nmap(g->g(image), f.mappedsignal)\n\n\n\n"
},

{
    "location": "reference.html#GtkReactive.player",
    "page": "Reference",
    "title": "GtkReactive.player",
    "category": "Function",
    "text": "player(range; style=\"with-textbox\", id=1)\nplayer(slice::Signal{Int}, range; style=\"with-textbox\", id=1)\n\nCreate a movie-player widget. This includes the standard play and stop buttons and a slider; style \"with-textbox\" also includes play backwards, step forward/backward, and a textbox for entering a slice by keyboard.\n\nYou can create up to two player widgets for the same GUI, as long as you pass id=1 and id=2, respectively.\n\n\n\n"
},

{
    "location": "reference.html#Input-widgets-1",
    "page": "Reference",
    "title": "Input widgets",
    "category": "section",
    "text": "button\ncheckbox\ntogglebutton\nslider\ntextbox\ntextarea\ndropdown\nplayer"
},

{
    "location": "reference.html#GtkReactive.label",
    "page": "Reference",
    "title": "GtkReactive.label",
    "category": "Function",
    "text": "label(value; widget=nothing, signal=nothing)\n\nCreate a text label displaying value as a string; new values may displayed by pushing to the widget. Optionally specify\n\nthe GtkLabel widget (by default, creates a new one)\nthe (Reactive.jl) signal coupled to this label (by default, creates a new signal)\n\n\n\n"
},

{
    "location": "reference.html#Output-widgets-1",
    "page": "Reference",
    "title": "Output widgets",
    "category": "section",
    "text": "label"
},

{
    "location": "reference.html#GtkReactive.canvas",
    "page": "Reference",
    "title": "GtkReactive.canvas",
    "category": "Function",
    "text": "canvas(U=DeviceUnit, w=-1, h=-1) - c::GtkReactive.Canvas\n\nCreate a canvas for drawing and interaction. Optionally specify the width w and height h. U refers to the units for the canvas (for both drawing and reporting mouse pointer positions), see DeviceUnit and UserUnit. See also GtkReactive.Canvas.\n\n\n\n"
},

{
    "location": "reference.html#GtkReactive.Canvas",
    "page": "Reference",
    "title": "GtkReactive.Canvas",
    "category": "Type",
    "text": "GtkReactive.Canvas{U}(w=-1, h=-1, own=true)\n\nCreate a canvas for drawing and interaction. The relevant fields are:\n\ncanvas: the \"raw\" Gtk widget (from Gtk.jl)\nmouse: the MouseHandler{U} for this canvas.\n\nSee also canvas.\n\n\n\n"
},

{
    "location": "reference.html#GtkReactive.MouseHandler",
    "page": "Reference",
    "title": "GtkReactive.MouseHandler",
    "category": "Type",
    "text": "MouseHandler{U<:CairoUnit}\n\nA type with Signal fields for which you can map callback actions. The fields are:\n\nbuttonpress for clicks (of type MouseButton);\nbuttonrelease for release events (of type MouseButton);\nmotion for move and drag events (of type MouseButton);\nscroll for wheelmouse or track-pad actions (of type MouseScroll);\n\nU should be either DeviceUnit or UserUnit and determines the coordinate system used for reporting mouse positions.\n\n\n\n"
},

{
    "location": "reference.html#GtkReactive.DeviceUnit",
    "page": "Reference",
    "title": "GtkReactive.DeviceUnit",
    "category": "Type",
    "text": "DeviceUnit(x)\n\nRepresent a number x as having \"device\" units (aka, screen pixels). See the Cairo documentation.\n\n\n\n"
},

{
    "location": "reference.html#GtkReactive.UserUnit",
    "page": "Reference",
    "title": "GtkReactive.UserUnit",
    "category": "Type",
    "text": "UserUnit(x)\n\nRepresent a number x as having \"user\" units, i.e., whatever units have been established with calls that affect the transformation matrix, e.g., Graphics.set_coordinates or Cairo.set_matrix.\n\n\n\n"
},

{
    "location": "reference.html#GtkReactive.XY",
    "page": "Reference",
    "title": "GtkReactive.XY",
    "category": "Type",
    "text": "XY(x, y)\n\nA type to hold x (horizontal), y (vertical) coordinates, where the number increases to the right and downward. If used to encode mouse pointer positions, the units of x and y are either DeviceUnit or UserUnit.\n\n\n\n"
},

{
    "location": "reference.html#GtkReactive.MouseButton",
    "page": "Reference",
    "title": "GtkReactive.MouseButton",
    "category": "Type",
    "text": "MouseButton(position, button, clicktype, modifiers)\n\nA type to hold information about a mouse button event (e.g., a click). position is the canvas position of the pointer (see XY). button is an integer identifying the button, where 1=left button, 2=middle button, 3=right button. clicktype may be BUTTON_PRESS or DOUBLE_BUTTON_PRESS. modifiers indicates whether any keys were held down during the click; they may be any combination of SHIFT, CONTROL, or MOD1 stored as a bitfield (test with btn.modifiers & SHIFT).\n\nThe fieldnames are the same as the argument names above.\n\nMouseButton{UserUnit}()\nMouseButton{DeviceUnit}()\n\nCreate a \"dummy\" MouseButton event. Often useful for the fallback to Reactive's filterwhen.\n\n\n\n"
},

{
    "location": "reference.html#GtkReactive.MouseScroll",
    "page": "Reference",
    "title": "GtkReactive.MouseScroll",
    "category": "Type",
    "text": "MouseScroll(position, direction, modifiers)\n\nA type to hold information about a mouse wheel scroll. position is the canvas position of the pointer (see XY). direction may be UP, DOWN, LEFT, or RIGHT. modifiers indicates whether any keys were held down during the click; they may be 0 (no modifiers) or any combination of SHIFT, CONTROL, or MOD1 stored as a bitfield.\n\nMouseScroll{UserUnit}()\nMouseScroll{DeviceUnit}()\n\nCreate a \"dummy\" MouseScroll event. Often useful for the fallback to Reactive's filterwhen.\n\n\n\n"
},

{
    "location": "reference.html#Graphics-1",
    "page": "Reference",
    "title": "Graphics",
    "category": "section",
    "text": "canvas\nGtkReactive.Canvas\nGtkReactive.MouseHandler\nDeviceUnit\nUserUnit\nGtkReactive.XY\nGtkReactive.MouseButton\nGtkReactive.MouseScroll"
},

{
    "location": "reference.html#GtkReactive.ZoomRegion",
    "page": "Reference",
    "title": "GtkReactive.ZoomRegion",
    "category": "Type",
    "text": "ZoomRegion(fullinds) -> zr\nZoomRegion(fullinds, currentinds) -> zr\nZoomRegion(img::AbstractMatrix) -> zr\n\nCreate a ZoomRegion object zr for selecting a rectangular region-of-interest for zooming and panning. fullinds should be a pair (yrange, xrange) of indices, or pass a matrix img from which the indices will be taken.\n\nzr.currentview holds the currently-active region of interest. zr.fullview stores the original fullinds from which zr was constructed; these are used to reset to the original limits and to confine zr.currentview.\n\n\n\n"
},

{
    "location": "reference.html#GtkReactive.pan_x",
    "page": "Reference",
    "title": "GtkReactive.pan_x",
    "category": "Function",
    "text": "pan_x(zr::ZoomRegion, frac) -> zr_new\n\nPan the x-axis by a fraction frac of the current x-view. frac>0 means that the coordinates shift right, which corresponds to a leftward shift of objects.\n\n\n\n"
},

{
    "location": "reference.html#GtkReactive.pan_y",
    "page": "Reference",
    "title": "GtkReactive.pan_y",
    "category": "Function",
    "text": "pan_y(zr::ZoomRegion, frac) -> zr_new\n\nPan the y-axis by a fraction frac of the current x-view. frac>0 means that the coordinates shift downward, which corresponds to an upward shift of objects.\n\n\n\n"
},

{
    "location": "reference.html#GtkReactive.zoom",
    "page": "Reference",
    "title": "GtkReactive.zoom",
    "category": "Function",
    "text": "zoom(zr::ZoomRegion, scaleview, pos::XY) -> zr_new\n\nZooms in (scaleview < 1) or out (scaleview > 1) by a scaling factor scaleview, in a manner centered on pos.\n\n\n\nzoom(zr::ZoomRegion, scaleview)\n\nZooms in (scaleview < 1) or out (scaleview > 1) by a scaling factor scaleview, in a manner centered around the current view region.\n\n\n\n"
},

{
    "location": "reference.html#GtkReactive.init_zoom_rubberband",
    "page": "Reference",
    "title": "GtkReactive.init_zoom_rubberband",
    "category": "Function",
    "text": "signals = init_zoom_rubberband(canvas::GtkReactive.Canvas,\n                               zr::Signal{ZoomRegion},\n                               initiate = btn->(btn.button == 1 && btn.clicktype == BUTTON_PRESS && btn.modifiers == CONTROL),\n                               reset = btn->(btn.button == 1 && btn.clicktype == DOUBLE_BUTTON_PRESS && btn.modifiers == CONTROL),\n                               minpixels = 2)\n\nInitialize rubber-band selection that updates zr. signals is a dictionary holding the Reactive.jl signals needed for rubber-banding; you can push true/false to signals[\"enabled\"] to turn rubber banding on and off, respectively. Your application is responsible for making sure that signals does not get garbage-collected (which would turn off rubberbanding).\n\ninitiate(btn) returns true when the condition for starting a rubber-band selection has been met (by default, clicking mouse button 1). The argument btn is a MouseButton event. reset(btn) returns true when restoring the full view (by default, double-clicking mouse button 1). minpixels can be used for aborting rubber-band selections smaller than some threshold.\n\n\n\n"
},

{
    "location": "reference.html#GtkReactive.init_zoom_scroll",
    "page": "Reference",
    "title": "GtkReactive.init_zoom_scroll",
    "category": "Function",
    "text": "signals = init_zoom_scroll(canvas::GtkReactive.Canvas,\n                           zr::Signal{ZoomRegion},\n                           filter::Function = evt->evt.modifiers == CONTROL,\n                           focus::Symbol = :pointer,\n                           factor = 2.0,\n                           flip = false)\n\nInitialize zooming-by-mouse-scroll for canvas and update zr. signals is a dictionary holding the Reactive.jl signals needed for scroll-zooming; you can push true/false to signals[\"enabled\"] to turn scroll-zooming on and off, respectively. Your application is responsible for making sure that signals does not get garbage-collected (which would turn off scroll-zooming).\n\nfilter is a function that returns true when the conditions for scroll-zooming are met; the argument is a MouseScroll event. The default is to hold down the CONTROL key while scrolling the mouse.\n\nThe focus keyword controls how the zooming progresses as you scroll the mouse wheel. :pointer means that whatever feature of the canvas is under the pointer will stay there as you zoom in or out. The other choice, :center, keeps the canvas centered on its current location.\n\nYou can change the amount of zooming via factor and the direction of zooming with flip.\n\n\n\n"
},

{
    "location": "reference.html#GtkReactive.init_pan_drag",
    "page": "Reference",
    "title": "GtkReactive.init_pan_drag",
    "category": "Function",
    "text": "signals = init_pan_drag(canvas::GtkReactive.Canvas,\n                        zr::Signal{ZoomRegion},\n                        initiate = btn->(btn.button == 1 && btn.clicktype == BUTTON_PRESS && btn.modifiers == 0))\n\nInitialize click-drag panning that updates zr. signals is a dictionary holding the Reactive.jl signals needed for pan-drag; you can push true/false to signals[\"enabled\"] to turn it on and off, respectively. Your application is responsible for making sure that signals does not get garbage-collected (which would turn off pan-dragging).\n\ninitiate(btn) returns true when the condition for starting click-drag panning has been met (by default, clicking mouse button 1). The argument btn is a MouseButton event.\n\n\n\n"
},

{
    "location": "reference.html#GtkReactive.init_pan_scroll",
    "page": "Reference",
    "title": "GtkReactive.init_pan_scroll",
    "category": "Function",
    "text": "signals = init_pan_scroll(canvas::GtkReactive.Canvas,\n                          zr::Signal{ZoomRegion},\n                          filter_x::Function = evt->evt.modifiers == SHIFT || event.direction == LEFT || event.direction == RIGHT,\n                          filter_y::Function = evt->evt.modifiers == 0 || event.direction == UP || event.direction == DOWN,\n                          xpanflip = false,\n                          ypanflip  = false)\n\nInitialize panning-by-mouse-scroll for canvas and update zr. signals is a dictionary holding the Reactive.jl signals needed for scroll-panning; you can push true/false to signals[\"enabled\"] to turn scroll-panning on and off, respectively. Your application is responsible for making sure that signals does not get garbage-collected (which would turn off scroll-panning).\n\nfilter_x and filter_y are functions that return true when the conditions for x- and y-scrolling are met; the argument is a MouseScroll event. The defaults are that vertical scrolling is triggered with an unmodified scroll, whereas horizontal scrolling is triggered by scrolling while holding down the SHIFT key.\n\nYou can flip the direction of either pan operation with xpanflip and ypanflip, respectively.\n\n\n\n"
},

{
    "location": "reference.html#Pan/zoom-1",
    "page": "Reference",
    "title": "Pan/zoom",
    "category": "section",
    "text": "ZoomRegion\npan_x\npan_y\nzoom\ninit_zoom_rubberband\ninit_zoom_scroll\ninit_pan_drag\ninit_pan_scroll"
},

{
    "location": "reference.html#GtkReactive.signal",
    "page": "Reference",
    "title": "GtkReactive.signal",
    "category": "Function",
    "text": "signal(w) -> s\n\nReturn the Reactive.jl Signal s associated with widget w.\n\n\n\n"
},

{
    "location": "reference.html#GtkReactive.frame",
    "page": "Reference",
    "title": "GtkReactive.frame",
    "category": "Function",
    "text": "frame(w) -> f\n\nReturn the GtkFrame f associated with widget w.\n\n\n\n"
},

{
    "location": "reference.html#GtkReactive.gc_preserve",
    "page": "Reference",
    "title": "GtkReactive.gc_preserve",
    "category": "Function",
    "text": "gc_preserve(widget::GtkWidget, obj)\n\nPreserve obj until widget has been destroyed.\n\n\n\n"
},

{
    "location": "reference.html#API-1",
    "page": "Reference",
    "title": "API",
    "category": "section",
    "text": "signal\nframe\nGtkReactive.gc_preserve"
},

]}
