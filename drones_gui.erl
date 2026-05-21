-module(drones_gui).
-behaviour(gen_server).
-include_lib("wx/include/wx.hrl").

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    Wx = wx:new(),
    Frame = wxFrame:new(Wx, -1, "Supervision Essaim de Drones", [{size, {600, 600}}]),
    Panel = wxPanel:new(Frame, [{style, ?wxFULL_REPAINT_ON_RESIZE}]),
    
    %% Empêche le scintillement de l'écran lors du rafraîchissement
    wxPanel:connect(Panel, erase_background, [{callback, fun(_Evt, _Obj) -> ok end}]),
    wxFrame:show(Frame),
    
    %% Cadence de rafraîchissement : 20 fois par seconde (toutes les 50ms)
    timer:send_interval(50, refresh_tick),
    {ok, #{panel => Panel}}.

handle_info(refresh_tick, State = #{panel := Panel}) ->
    %% On force le panel graphique à se redessiner
    DC = wxClientDC:new(Panel),
    BufferedDC = wxBufferedDC:new(DC),
    
    %% Dessin du fond d'écran sombre
    BackgroundBrush = wxBrush:new({35, 35, 35}),
    wxDC:setBackground(BufferedDC, BackgroundBrush),
    wxDC:clear(BufferedDC),
    
    %% Lecture des coordonnées stockées dans le contrôleur
    Data = drones_controller:get_all_states(),
    DronesMap = maps:get(drones, Data, #{}),
    StationsList = maps:get(stations, Data, []),

    %% Dessin des stations (Carrés bleus)
    BlueBrush = wxBrush:new({0, 100, 255}),
    wxDC:setBrush(BufferedDC, BlueBrush),
    dessiner_stations_rec(BufferedDC, StationsList),
    wxBrush:destroy(BlueBrush),
    
    %% Dessin de la flotte de drones (Cercles dynamiques)
    dessiner_les_drones_rec(BufferedDC, maps:to_list(DronesMap)),

    %% Libération propre des ressources graphiques OS
    wxBrush:destroy(BackgroundBrush),
    wxBufferedDC:destroy(BufferedDC),
    wxClientDC:destroy(DC),
    {noreply, State};

handle_info(_Evt, State) ->
    {noreply, State}.

%% =============================================================================
%% BOUCLES RECURSIVES DE DESSIN
%% =============================================================================

dessiner_stations_rec(_DC, []) -> ok;
dessiner_stations_rec(DC, [{SX, SY} | Reste]) ->
    wxDC:drawRectangle(DC, {trunc(SX)-15, trunc(SY)-15, 30, 30}),
    dessiner_stations_rec(DC, Reste).

dessiner_les_drones_rec(_DC, []) -> ok;
dessiner_les_drones_rec(DC, [{Id, MapData} | Reste]) ->
    {X, Y} = maps:get(pos, MapData),
    B = maps:get(battery, MapData),
    
    %% Choix de la couleur selon le niveau de batterie (Vert ou Rouge)
    Couleur = if B < 25.0 -> {255, 50, 50}; true -> {50, 255, 50} end,
    Brush = wxBrush:new(Couleur),
    wxDC:setBrush(DC, Brush),
    
    %% Dessin du corps du drone
    wxDC:drawCircle(DC, {trunc(X), trunc(Y)}, 14),
    
    %% Affichage du numéro d'ID du drone au centre du cercle
    wxDC:setTextForeground(DC, {0, 0, 0}),
    wxDC:drawText(DC, integer_to_list(Id), {trunc(X)-4, trunc(Y)-7}),
    
    wxBrush:destroy(Brush),
    dessiner_les_drones_rec(DC, Reste).

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.
code_change(_Old, State, _Extra) -> {ok, State}.