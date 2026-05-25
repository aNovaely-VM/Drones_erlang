-module(drones_gui).
-behaviour(gen_server).
-include_lib("wx/include/wx.hrl").


%% nb: c'est le module qui affiche la fenetre graphique avec les drones
%% utilise la librairie wx (wxWidgets) pour dessiner


-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

%% demarre la gui
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% initialisation: on cree la fenetre et on lance le timer de rafraichissement
init([]) ->
    %% wx:new() initialise la librairie graphique
    Wx = wx:new(),
    %% on cree une fenetre de 600x600 pixels
    Frame = wxFrame:new(Wx, -1, "Supervision Essaim de Drones", [{size, {600, 600}}]),
    Panel = wxPanel:new(Frame, [{style, ?wxFULL_REPAINT_ON_RESIZE}]),
    
    %% nb: cette ligne empeche le scintillement de l'ecran (flickering)
    wxPanel:connect(Panel, erase_background, [{callback, fun(_Evt, _Obj) -> ok end}]),
    wxFrame:show(Frame),
    
    %% on rafraichit l'ecran toutes les 16ms (environ 60 fps)
    timer:send_interval(16, refresh_tick),
    {ok, #{panel => Panel}}.


%% HANDLE_INFO - gere le tick de rafraichissement
%% nb: c'est ici qu'on dessine tout a chaque frame


handle_info(refresh_tick, State = #{panel := Panel}) ->
    %% on cree un contexte de dessin avec double buffering (evite le flickering)
    DC = wxClientDC:new(Panel),
    BufferedDC = wxBufferedDC:new(DC),
    
    %% on dessine le fond en gris fonce
    BackgroundBrush = wxBrush:new({35, 35, 35}),
    wxDC:setBackground(BufferedDC, BackgroundBrush),
    wxDC:clear(BufferedDC),
    
    %% on recupere les donnees des drones depuis le controleur
    Data = drones_controller:get_all_states(),
    DronesMap = maps:get(drones, Data, #{}),
    StationsList = maps:get(stations, Data, []),

    %% on dessine les stations en bleu (carres)
    BlueBrush = wxBrush:new({0, 100, 255}),
    wxDC:setBrush(BufferedDC, BlueBrush),
    dessiner_stations_rec(BufferedDC, StationsList),
    wxBrush:destroy(BlueBrush),
    
    %% on dessine les drones (cercles avec couleur selon batterie)
    dessiner_les_drones_rec(BufferedDC, maps:to_list(DronesMap)),

    %% nb: important de liberer les ressources graphiques sinon fuite memoire!
    wxBrush:destroy(BackgroundBrush),
    wxBufferedDC:destroy(BufferedDC),
    wxClientDC:destroy(DC),
    {noreply, State};

handle_info(_Evt, State) ->
    {noreply, State}.

%% FONCTIONS DE DESSIN RECURSIVES


%% dessine les stations (carres bleus) - pas utilise pour l'instant
dessiner_stations_rec(_DC, []) -> ok;
dessiner_stations_rec(DC, [{SX, SY} | Reste]) ->
    wxDC:drawRectangle(DC, {trunc(SX)-15, trunc(SY)-15, 30, 30}),
    dessiner_stations_rec(DC, Reste).

%% dessine chaque drone un par un
dessiner_les_drones_rec(_DC, []) -> ok;
dessiner_les_drones_rec(DC, [{Id, MapData} | Reste]) ->
    {X, Y} = maps:get(pos, MapData),
    B = maps:get(battery, MapData),
    
    %% nb: couleur verte si batterie ok, rouge si batterie faible (<25%)
    Couleur = if B < 25.0 -> {255, 50, 50}; true -> {50, 255, 50} end,
    Brush = wxBrush:new(Couleur),
    wxDC:setBrush(DC, Brush),
    
    %% on dessine le cercle du drone (rayon 14 pixels)
    wxDC:drawCircle(DC, {trunc(X), trunc(Y)}, 14),
    
    %% on affiche le numero du drone au centre
    wxDC:setTextForeground(DC, {0, 0, 0}),
    wxDC:drawText(DC, integer_to_list(Id), {trunc(X)-4, trunc(Y)-7}),
    
    wxBrush:destroy(Brush),
    dessiner_les_drones_rec(DC, Reste).

%% callbacks obligatoires pour gen_server
handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.
code_change(_Old, State, _Extra) -> {ok, State}.