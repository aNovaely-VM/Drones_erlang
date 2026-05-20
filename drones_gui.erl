-module(drones_gui).
-behaviour(gen_server).
-include_lib("wx/include/wx.hrl").

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    Wx = wx:new(),
    Frame = wxFrame:new(Wx, -1, "Drone Monitor OTP", [{size, {600, 600}}]),
    Panel = wxPanel:new(Frame),
    
    %% On définit une couleur de fond pour voir si le panel existe
    wxWindow:setBackgroundColour(Panel, {30, 30, 30}), 
    
    wxFrame:show(Frame),
    
    %% CORRECTION ICI : Enlever [callback] pour recevoir les messages dans handle_info
    wxPanel:connect(Panel, paint),
    
    timer:send_interval(100, refresh_tick),
    {ok, #{panel => Panel}}.

handle_info(refresh_tick, State = #{panel := Panel}) ->
    wxWindow:refresh(Panel),
    {noreply, State};

handle_info(#wx{event = #wxPaint{}}, State = #{panel := Panel}) ->
    DC = wxPaintDC:new(Panel),
    wxDC:setBrush(DC, ?wxBLUE_BRUSH),
    
    %% 1. On récupère les données
    Data = drones_controller:get_all_states(),
    Drones = maps:get(drones, Data, #{}),
    Stations = maps:get(stations, Data, []),

    %% 2. DEBUG CONSOLE : Pour vérifier que le dessin s'exécute
    io:format("GUI : Dessin de ~p drones et ~p stations~n", [maps:size(Drones), length(Stations)]),

    %% 3. Dessin des stations (Carrés bleus)
    wxDC:setPen(DC, ?wxWHITE_PEN),
    wxDC:setBrush(DC, ?wxBLUE_BRUSH),
    [wxDC:drawRectangle(DC, {trunc(SX)-15, trunc(SY)-15, 30, 30}) || {SX, SY} <- Stations],
    
    %% 4. Dessin des drones
    maps:map(fun(Id, D) ->
        {X, Y} = maps:get(pos, D),
        B = maps:get(battery, D),
        
        %% Choisir la couleur
        Color = if B < 25 -> {255, 0, 0}; true -> {0, 255, 0} end,
        Brush = wxBrush:new(Color),
        wxDC:setBrush(DC, Brush),
        
        %% Dessiner le cercle du drone
        wxDC:drawCircle(DC, {trunc(X), trunc(Y)}, 12),
        
        %% Dessiner l'ID du drone à côté
        wxDC:drawText(DC, integer_to_list(Id), {trunc(X)+15, trunc(Y)-10}),
        
        wxBrush:destroy(Brush)
    end, Drones),
    
    wxPaintDC:destroy(DC),
    {noreply, State};

handle_info(_Msg, State) -> {noreply, State}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.
code_change(_OldVsn, State, _Extra) -> {ok, State}.
