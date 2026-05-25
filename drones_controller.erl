-module(drones_controller).
-behaviour(gen_server).


%% nb: c'est le "cerveau" du systeme, il gere tous les drones et leurs etats
%% c'est un gen_server donc il tourne en boucle et repond aux messages


-export([start_link/0, register_drone/2, update_state/3, get_all_states/0]).
-export([broadcast_mission/3, send_mission_to_drone/3, emergency_stop/0, apply_formation/1, random_exploration/0, recharge_base/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

%% demarre le controleur et l'enregistre sous le nom drones_controller
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% init: on cree juste une map vide pour stocker les drones et les stations
init([]) ->
    {ok, #{drones => #{}, stations => []}}.


%% API PUBLIQUE - les fonctions qu'on appelle de l'exterieur


%% permet a un drone de s'enregistrer aupres du controleur
register_drone(Pid, Id) ->
    gen_server:cast(?MODULE, {register, Pid, Id}).

%% met a jour la position et batterie d'un drone dans le controleur
update_state(Id, Pos, Battery) ->
    gen_server:cast(?MODULE, {update, Id, Pos, Battery}).

%% retourne l'etat complet de tous les drones (utilise par la gui et le client)
get_all_states() ->
    gen_server:call(?MODULE, get_all_states).

%% envoie une mission (coordonnees X,Y) a TOUS les drones
broadcast_mission(X, Y, _Node) ->
    gen_server:cast(?MODULE, {broadcast_mission, float(X), float(Y)}).

%% nb: nouvelle fonction pour envoyer une mission a UN SEUL drone specifique
send_mission_to_drone(DroneId, X, Y) ->
    gen_server:cast(?MODULE, {send_mission_to_drone, DroneId, float(X), float(Y)}).

%% fait bouger les drones dans des directions aleatoires
random_exploration() ->
    gen_server:cast(?MODULE, random_exploration).

%% arret d'urgence: tous les drones s'arretent sur place
emergency_stop() ->
    gen_server:cast(?MODULE, emergency_stop).

%% recharge les drones qui sont a la base
recharge_base() ->
    gen_server:cast(?MODULE, recharge_base).

%% applique une formation geometrique (carre, chasse, cercle)
apply_formation(Type) ->
    gen_server:cast(?MODULE, {apply_formation, Type}).



%% CALLBACKS DU GEN_SERVER - la logique interne qui repond aux messages


%% quand un nouveau drone s'enregistre, on l'ajoute a notre map
handle_cast({register, Pid, Id}, State = #{drones := Drones}) ->
    NouveauDrone = #{pid => Pid, pos => {300.0, 300.0}, battery => 100.0},
    NouvellesDrones = maps:put(Id, NouveauDrone, Drones),
    io:format("[Controleur] Drone ~p enregistre (PID: ~p)~n", [Id, Pid]),
    {noreply, State#{drones => NouvellesDrones}};

%% quand un drone envoie sa nouvelle position/batterie, on met a jour
handle_cast({update, Id, Pos, Battery}, State = #{drones := Drones}) ->
    case maps:find(Id, Drones) of
        {ok, DataDuDrone} ->
            DroneMisAJour = DataDuDrone#{pos => Pos, battery => Battery},
            NouvellesDrones = maps:put(Id, DroneMisAJour, Drones),
            {noreply, State#{drones => NouvellesDrones}};
        error ->
            %% le drone n'existe pas, on ignore
            {noreply, State}
    end;

%% broadcast: on envoie les coordonnees a tous les drones
handle_cast({broadcast_mission, X, Y}, State = #{drones := Drones}) ->
    envoyer_cible_rec(maps:values(Drones), X, Y),
    {noreply, State};

%% nb: envoie une mission a un drone specifique par son Id
handle_cast({send_mission_to_drone, DroneId, X, Y}, State = #{drones := Drones}) ->
    case maps:find(DroneId, Drones) of
        {ok, DroneData} ->
            Pid = maps:get(pid, DroneData),
            gen_server:cast(Pid, {eval_mission, X, Y}),
            io:format("[Controleur] Mission envoyee au drone ~p -> (~p, ~p)~n", [DroneId, X, Y]);
        error ->
            io:format("[Controleur] Erreur: drone ~p pas trouve!~n", [DroneId])
    end,
    {noreply, State};

%% exploration aleatoire: chaque drone va a une position random
handle_cast(random_exploration, State = #{drones := Drones}) ->
    exploration_aleatoire_rec(maps:values(Drones)),
    {noreply, State};

%% arret d'urgence: on dit a chaque drone de stopper
handle_cast(emergency_stop, State = #{drones := Drones}) ->
    envoyer_stop_rec(maps:values(Drones)),
    {noreply, State};

%% recharge: on dit aux drones de se recharger
handle_cast(recharge_base, State = #{drones := Drones}) ->
    envoyer_recharge_rec(maps:values(Drones)),
    {noreply, State};

%% formation: on calcule les positions et on les assigne aux drones
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

%% si on recoit un message qu'on connait pas, on l'ignore
handle_cast(_Msg, State) ->
    {noreply, State}.

%% repond a la demande d'etat complet
handle_call(get_all_states, _From, State) ->
    {reply, State, State};

handle_call(_Req, _From, State) ->
    {reply, ok, State}.

%% ces callbacks sont obligatoires pour gen_server mais on s'en sert pas vraiment
handle_info(_Info, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.
code_change(_Old, State, _Extra) -> {ok, State}.


%% FONCTIONS RECURSIVES - on parcourt les listes de drones
%% nb: c'est la facon erlang de faire des boucles (pas de for/while ici!)


%% cas de base: liste vide = on a fini
envoyer_cible_rec([], _X, _Y) -> ok;
%% cas recursif: on traite le premier drone puis on rappelle la fonction
envoyer_cible_rec([DroneData | Reste], X, Y) ->
    Pid = maps:get(pid, DroneData),
    gen_server:cast(Pid, {eval_mission, X, Y}),
    envoyer_cible_rec(Reste, X, Y).

%% pareil mais avec des coordonnees aleatoires pour chaque drone
exploration_aleatoire_rec([]) -> ok;
exploration_aleatoire_rec([DroneData | Reste]) ->
    Pid = maps:get(pid, DroneData),
    RandX = float(rand:uniform(500) + 50),
    RandY = float(rand:uniform(500) + 50),
    gen_server:cast(Pid, {eval_mission, RandX, RandY}),
    exploration_aleatoire_rec(Reste).

%% envoie l'ordre de stop a chaque drone
envoyer_stop_rec([]) -> ok;
envoyer_stop_rec([DroneData | Reste]) ->
    Pid = maps:get(pid, DroneData),
    gen_server:cast(Pid, stop),
    envoyer_stop_rec(Reste).

%% envoie l'ordre de recharge a chaque drone
envoyer_recharge_rec([]) -> ok;
envoyer_recharge_rec([DroneData | Reste]) ->
    Pid = maps:get(pid, DroneData),
    gen_server:cast(Pid, recharge),
    envoyer_recharge_rec(Reste).

%% assigne les positions de formation a chaque drone
attribuer_formation_rec([], _) -> ok;
attribuer_formation_rec(_, []) -> ok;
attribuer_formation_rec([DroneData | ResteDrones], [{X, Y} | ResteCoords]) ->
    Pid = maps:get(pid, DroneData),
    gen_server:cast(Pid, {eval_mission, X, Y}),
    attribuer_formation_rec(ResteDrones, ResteCoords).


%% GENERATION DES COORDONNEES DE FORMATION
%% nb: c'est ici qu'on fait les maths pour placer les drones en forme
%% le centre c'est (300, 300) parce que c'est le milieu de la fenetre 600x600


%% cas de base: on a genere toutes les coordonnees
generer_coords(_Type, Max, Max) -> [];

%% formation carre: on place les drones en grille
generer_coords(carre, I, Max) ->
    Cote = ceil(math:sqrt(Max)),
    Rangee = I div Cote,
    Colonne = I rem Cote,
    X = 300.0 + (Colonne - (Cote - 1) / 2.0) * 60.0,
    Y = 300.0 + (Rangee - (Cote - 1) / 2.0) * 60.0,
    [{X, Y} | generer_coords(carre, I + 1, Max)];

%% formation chasse (V): le leader devant, les autres en diagonale derriere
generer_coords(chasse, I, Max) ->
    if
        I == 0 -> 
            [{300.0, 150.0} | generer_coords(chasse, I + 1, Max)];
        I rem 2 == 1 -> 
            Facteur = (I + 1) div 2,
            [{300.0 - (Facteur * 50.0), 150.0 + (Facteur * 50.0)} | generer_coords(chasse, I + 1, Max)];
        true -> 
            Facteur = I div 2,
            [{300.0 + (Facteur * 50.0), 150.0 + (Facteur * 50.0)} | generer_coords(chasse, I + 1, Max)]
    end;

%% formation cercle: on utilise cos et sin pour placer les drones en rond
generer_coords(cercle, I, Max) ->
    Rayon = 120.0,
    Angle = I * (2.0 * math:pi() / Max),
    X = 300.0 + Rayon * math:cos(Angle),
    Y = 300.0 + Rayon * math:sin(Angle),
    [{X, Y} | generer_coords(cercle, I + 1, Max)].