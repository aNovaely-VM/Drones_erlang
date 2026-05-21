-module(drones_worker).
-behaviour(gen_server).

-export([start_link/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

start_link(Id) ->
    gen_server:start_link(?MODULE, [Id], []).

init([Id]) ->
    %% Position de départ aléatoire sur l'écran
    X = float(rand:uniform(400) + 50),
    Y = float(rand:uniform(400) + 50),
    drones_controller:register_drone(self(), Id),
    
    %% Horloge interne : déclenche un message 'tick' toutes les secondes (1000ms)
    timer:send_interval(1000, tick),
    
    {ok, #{id => Id, pos => {X, Y}, target => {X, Y}, battery => 100.0, status => idle}}.

handle_cast({eval_mission, MX, MY}, State) ->
    Bat = maps:get(battery, State),
    if
        Bat > 20.0 ->
            %% Le drone accepte la mission et change de cible
            {noreply, State#{target => {MX, MY}, status => mission}};
        true ->
            {noreply, State}
    end;

handle_cast(stop, State) ->
    {X, Y} = maps:get(pos, State),
    %% On fige le drone sur sa position actuelle
    {noreply, State#{target => {X, Y}, status => idle}};

handle_cast(_Msg, State) -> 
    {noreply, State}.

handle_info(tick, State) ->
    Id = maps:get(id, State),
    {X, Y} = maps:get(pos, State),
    {TX, TY} = maps:get(target, State),
    Bat = maps:get(battery, State),
    Status = maps:get(status, State),

    %% Calcul du déplacement pas à pas
    NewX = avancer_vers(X, TX),
    NewY = avancer_vers(Y, TY),

    %% Consommation électrique : consomme plus s'il vole
    ModifBat = if (X /= TX) or (Y /= TY) -> 1.5; true -> 0.2 end,
    NewBat = lists:max([0.0, Bat - ModifBat]),

    %% Gestion de la sécurité batterie faible
    {FinalTarget, FinalStatus} = if
        NewBat < 20.0 -> 
            {{300.0, 300.0}, returning}; %% Retour automatique à la base
        true -> 
            {{TX, TY}, Status}
    end,

    %% Notification au contrôleur de notre nouvelle position
    drones_controller:update_state(Id, {NewX, NewY}, NewBat),

    {noreply, State#{pos => {NewX, NewY}, target => {FinalTarget}, battery => NewBat, status => FinalStatus}};

handle_info(_Info, State) -> 
    {noreply, State}.

%% Fonction outil pour simuler un déplacement de 15 pixels max par seconde
avancer_vers(Actuel, Cible) ->
    Diff = Cible - Actuel,
    if
        Diff > 15.0 -> Actuel + 15.0;
        Diff < -15.0 -> Actuel - 15.0;
        true -> Cible
    end.

handle_call(_Req, _From, State) -> {reply, ok, State}.
terminate(_Reason, _State) -> ok.
code_change(_Old, State, _Extra) -> {ok, State}.