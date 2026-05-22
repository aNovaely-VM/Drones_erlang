-module(drones_controller).
-behaviour(gen_server).

-export([start_link/0, register_drone/2, update_state/3, get_all_states/0]).
-export([broadcast_mission/3, emergency_stop/0, apply_formation/1, random_exploration/0, recharge_base/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    %% On stocke tout simplement dans le State du gen_server :
    %% Une map pour les drones et une liste pour les stations.
    {ok, #{drones => #{}, stations => []}}.

%% =============================================================================
%% API PUBLIQUE (Appelée par les workers ou le client)
%% =============================================================================

register_drone(Pid, Id) ->
    gen_server:cast(?MODULE, {register, Pid, Id}).

update_state(Id, Pos, Battery) ->
    gen_server:cast(?MODULE, {update, Id, Pos, Battery}).

get_all_states() ->
    gen_server:call(?MODULE, get_all_states).

broadcast_mission(X, Y, _Node) ->
    gen_server:cast(?MODULE, {broadcast_mission, float(X), float(Y)}).

random_exploration() ->
    gen_server:cast(?MODULE, random_exploration).

emergency_stop() ->
    gen_server:cast(?MODULE, emergency_stop).

recharge_base() ->
    gen_server:cast(?MODULE, recharge_base).

apply_formation(Type) ->
    gen_server:cast(?MODULE, {apply_formation, Type}).


%% =============================================================================
%% CALLBACKS DU GEN_SERVER (Logique interne)
%% =============================================================================

handle_cast({register, Pid, Id}, State = #{drones := Drones}) ->
    NouveauDrone = #{pid => Pid, pos => {300.0, 300.0}, battery => 100.0},
    NouvellesDrones = maps:put(Id, NouveauDrone, Drones),
    io:format("[Controleur] Drone ~p enregistre (PID: ~p)~n", [Id, Pid]),
    {noreply, State#{drones => NouvellesDrones}};

handle_cast({update, Id, Pos, Battery}, State = #{drones := Drones}) ->
    case maps:find(Id, Drones) of
        {ok, DataDuDrone} ->
            DroneMisAJour = DataDuDrone#{pos => Pos, battery => Battery},
            NouvellesDrones = maps:put(Id, DroneMisAJour, Drones),
            {noreply, State#{drones => NouvellesDrones}};
        error ->
            {noreply, State}
    end;

handle_cast({broadcast_mission, X, Y}, State = #{drones := Drones}) ->
    envoyer_cible_rec(maps:values(Drones), X, Y),
    {noreply, State};

handle_cast(random_exploration, State = #{drones := Drones}) ->
    exploration_aleatoire_rec(maps:values(Drones)),
    {noreply, State};

handle_cast(emergency_stop, State = #{drones := Drones}) ->
    envoyer_stop_rec(maps:values(Drones)),
    {noreply, State};

handle_cast(recharge_base, State = #{drones := Drones}) ->
    envoyer_recharge_rec(maps:values(Drones)),
    {noreply, State};

handle_cast({apply_formation, Type}, State = #{drones := Drones}) ->
    ListeDrones = maps:values(Drones),
    NbDrones = length(ListeDrones),
    if
        NbDrones > 0 ->
            Coords = generer_coords(Type, 0, NbDrones),
            attribuer_formation_rec(ListeDrones, Coords);
        true ->
            ok
    end,
    {noreply, State};

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_call(get_all_states, _From, State) ->
    %% On renvoie le State tel quel car il a déjà la bonne structure pour la GUI
    {reply, State, State};

handle_call(_Req, _From, State) ->
    {reply, ok, State}.

handle_info(_Info, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.
code_change(_Old, State, _Extra) -> {ok, State}.

%% =============================================================================
%% FONCTIONS RECURSIVES DE PARCOURS
%% =============================================================================

envoyer_cible_rec([], _X, _Y) -> ok;
envoyer_cible_rec([DroneData | Reste], X, Y) ->
    Pid = maps:get(pid, DroneData),
    gen_server:cast(Pid, {eval_mission, X, Y}),
    envoyer_cible_rec(Reste, X, Y).

exploration_aleatoire_rec([]) -> ok;
exploration_aleatoire_rec([DroneData | Reste]) ->
    Pid = maps:get(pid, DroneData),
    RandX = float(rand:uniform(500) + 50),
    RandY = float(rand:uniform(500) + 50),
    gen_server:cast(Pid, {eval_mission, RandX, RandY}),
    exploration_aleatoire_rec(Reste).

envoyer_stop_rec([]) -> ok;
envoyer_stop_rec([DroneData | Reste]) ->
    Pid = maps:get(pid, DroneData),
    gen_server:cast(Pid, stop),
    envoyer_stop_rec(Reste).

envoyer_recharge_rec([]) -> ok;
envoyer_recharge_rec([DroneData | Reste]) ->
    Pid = maps:get(pid, DroneData),
    gen_server:cast(Pid, recharge),
    envoyer_recharge_rec(Reste).

attribuer_formation_rec([], _) -> ok;
attribuer_formation_rec(_, []) -> ok;
attribuer_formation_rec([DroneData | ResteDrones], [{X, Y} | ResteCoords]) ->
    Pid = maps:get(pid, DroneData),
    gen_server:cast(Pid, {eval_mission, X, Y}),
    attribuer_formation_rec(ResteDrones, ResteCoords).

%% Génération mathématique des positions (Centre 300, 300)
generer_coords(_Type, Max, Max) -> [];
generer_coords(carre, I, Max) ->
    Cote = ceil(math:sqrt(Max)),
    Rangee = I div Cote,
    Colonne = I rem Cote,
    X = 300.0 + (Colonne - (Cote - 1) / 2.0) * 60.0,
    Y = 300.0 + (Rangee - (Cote - 1) / 2.0) * 60.0,
    [{X, Y} | generer_coords(carre, I + 1, Max)];

generer_coords(chasse, I, Max) ->
    if
        I == 0 -> [{300.0, 150.0} | generer_coords(chasse, I + 1, Max)];
        I rem 2 == 1 -> 
            Facteur = (I + 1) div 2,
            [{300.0 - (Facteur * 50.0), 150.0 + (Facteur * 50.0)} | generer_coords(chasse, I + 1, Max)];
        true -> 
            Facteur = I div 2,
            [{300.0 + (Facteur * 50.0), 150.0 + (Facteur * 50.0)} | generer_coords(chasse, I + 1, Max)]
    end;

generer_coords(cercle, I, Max) ->
    Rayon = 120.0,
    Angle = I * (2.0 * math:pi() / Max),
    X = 300.0 + Rayon * math:cos(Angle),
    Y = 300.0 + Rayon * math:sin(Angle),
    [{X, Y} | generer_coords(cercle, I + 1, Max)].