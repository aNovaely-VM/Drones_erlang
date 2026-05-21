-module(drones_controller).
-behaviour(gen_server).

%% Fonctions d'interface
-export([start_link/0, register_drone/2, update_state/3, get_all_states/0]).
-export([broadcast_mission/3, emergency_stop/0, apply_formation/1]).

%% Callbacks de gen_server
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    %% Table ETS partagée pour stocker l'état global
    ets:new(drones_state, [named_table, public, set]),
    ets:insert(drones_state, {stations, []}),
    {ok, #{}}.

%% Enregistrement d'un drone
register_drone(Pid, Id) ->
    ets:insert(drones_state, {Id, #{pid => Pid, pos => {300.0, 300.0}, battery => 100.0}}),
    io:format("[Controleur] Drone ~p enregistre (PID: ~p)~n", [Id, Pid]),
    ok.

%% Mise à jour des positions envoyée par les drones
update_state(Id, Pos, Battery) ->
    case ets:lookup(drones_state, Id) of
        [{Id, Data}] ->
            ets:insert(drones_state, {Id, Data#{pos => Pos, battery => Battery}});
        [] -> 
            ok
    end,
    ok.

%% Récupération des données pour l'affichage graphique (Format compatible avec drones_gui)
get_all_states() ->
    ListeGlobale = ets:tab2list(drones_state),
    Stations = chercher_stations(ListeGlobale),
    DronesList = extraire_uniquement_drones(ListeGlobale),
    #{drones => maps:from_list(DronesList), stations => Stations}.

%% Envoi d'une cible unique à tous les drones
broadcast_mission(X, Y, _Node) ->
    io:format("[Controleur] Envoi de la cible (~p, ~p) a tout l'essaim~n", [X, Y]),
    ListeGlobale = ets:tab2list(drones_state),
    Drones = extraire_uniquement_drones(ListeGlobale),
    envoyer_cible_rec(Drones, float(X), float(Y)),
    ok.

%% Arrêt d'urgence de la flotte
emergency_stop() ->
    io:format("[Controleur] ARRET D'URGENCE DIFFUSE !~n"),
    ListeGlobale = ets:tab2list(drones_state),
    Drones = extraire_uniquement_drones(ListeGlobale),
    envoyer_stop_rec(Drones),
    ok.

%% Gestion des formations géométriques
apply_formation(Type) ->
    ListeGlobale = ets:tab2list(drones_state),
    Drones = extraire_uniquement_drones(ListeGlobale),
    NbDrones = length(Drones),
    if
        NbDrones > 0 ->
            Coords = generer_coords(Type, 0, NbDrones),
            attribuer_formation_rec(Drones, Coords),
            io:format("[Controleur] Formation ~p executee~n", [Type]);
        true ->
            io:format("[Controleur] Aucun drone disponible~n")
    end,
    ok.

%% =============================================================================
%% FONCTIONS RECURSIVES DE PARCOURS (Style purement académique)
%% =============================================================================

chercher_stations([]) -> [];
chercher_stations([{stations, S} | _]) -> S;
chercher_stations([_ | Reste]) -> chercher_stations(Reste).

extraire_uniquement_drones([]) -> [];
extraire_uniquement_drones([{stations, _} | Reste]) -> extraire_uniquement_drones(Reste);
extraire_uniquement_drones([{Id, Data} | Reste]) -> [{Id, Data} | extraire_uniquement_drones(Reste)].

envoyer_cible_rec([], _X, _Y) -> ok;
envoyer_cible_rec([{_Id, Data} | Reste], X, Y) ->
    Pid = maps:get(pid, Data),
    gen_server:cast(Pid, {eval_mission, X, Y}),
    envoyer_cible_rec(Reste, X, Y).

envoyer_stop_rec([]) -> ok;
envoyer_stop_rec([{_Id, Data} | Reste]) ->
    Pid = maps:get(pid, Data),
    gen_server:cast(Pid, stop),
    envoyer_stop_rec(Reste).

attribuer_formation_rec([], _) -> ok;
attribuer_formation_rec(_, []) -> ok;
attribuer_formation_rec([{_Id, Data} | ResteDrones], [{X, Y} | ResteCoords]) ->
    Pid = maps:get(pid, Data),
    gen_server:cast(Pid, {eval_mission, X, Y}),
    attribuer_formation_rec(ResteDrones, ResteCoords).

%% Génération des coordonnées mathématiques
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

%% Callbacks obligatoires inutilisés
handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.
handle_info(_Info, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.
code_change(_Old, State, _Extra) -> {ok, State}.