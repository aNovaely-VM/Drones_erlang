-module(drones_worker).
-behaviour(gen_server).

%% nb: c'est le module qui represente un drone individuel
%% chaque drone est un processus gen_server qui gere sa position et sa batterie

%% la vitesse de recharge en % par tick (modifiable si tu veux)
-define(VITESSE_RECHARGE, 15.0).

-export([start_link/1, evaluate_mission/3]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

%% demarre un nouveau drone avec un Id unique
start_link(Id) ->
    gen_server:start_link(?MODULE, [Id], []).

%% fonction pour donner une mission a un drone (pas utilisee directement ici)
evaluate_mission(Pid, X, Y) -> 
    gen_server:cast(Pid, {eval_mission, float(X), float(Y)}).

%% initialisation du drone: position aleatoire, batterie a 100%
init([Id]) ->
    %% on spawn le drone a une position random dans la zone 500x500
    X = float(rand:uniform(500)), 
    Y = float(rand:uniform(500)),
    %% on s'enregistre aupres du controleur
    drones_controller:register_drone(self(), Id),
    %% timer qui envoie un message "tick" toutes les 150ms pour mettre a jour
    timer:send_interval(150, tick),
    %% nb: la batterie commence a 500 mais ca represente 100% (c'est bizarre mais ca marche)
    {ok, #{id => Id, pos => {X, Y}, target => {X, Y}, battery => 100.0, status => idle}}.

%% on utilise pas handle_call dans ce module
handle_call(_Request, _From, State) -> {reply, ok, State}.

%% HANDLE_CAST - gere les messages asynchrones qu'on recoit

%% quand on recoit une nouvelle mission, on met a jour la cible
%% nb: on ignore si le drone est en train de recharger
handle_cast({eval_mission, MX, MY}, State = #{status := StatusActuel}) ->
    if
        StatusActuel /= recharging ->
            {noreply, State#{target => {MX, MY}, status => mission}};
        true ->
            {noreply, State}
    end;

%% ordre de stop: le drone s'arrete sur place (target = position actuelle)
handle_cast(stop, State = #{pos := {X, Y}}) ->
    {noreply, State#{status => idle, target => {X, Y}}};

%% ordre de recharge: le drone passe en mode recharge
handle_cast(recharge, State) ->
    {noreply, State#{status => recharging}};

%% message inconnu: on l'ignore
handle_cast(_Msg, State) -> 
    {noreply, State}.

%% HANDLE_INFO - gere le tick (mise a jour periodique)
%% nb: c'est ici que la magie se passe, le drone bouge et perd de la batterie

handle_info(tick, State = #{id := Id, pos := {X, Y}, target := {TX, TY}, battery := Bat, status := StatusActuel}) ->
    if
        %% si on recharge, on augmente la batterie
        StatusActuel == recharging ->
            NouvelleBatterie = min(100.0, Bat + ?VITESSE_RECHARGE),
            %% quand on atteint 100%, on repasse en idle
            NouveauStatus = if NouvelleBatterie >= 100.0 -> idle; true -> recharging end,
            drones_controller:update_state(Id, {X, Y}, NouvelleBatterie),
            {noreply, State#{battery => NouvelleBatterie, status => NouveauStatus}};
            
        %% sinon, on bouge vers la cible
        true ->
            %% on calcule la nouvelle position (on avance de 10 pixels max)
            NouvelleX = move(X, TX),
            NouvelleY = move(Y, TY),
            
            %% cout en energie: 1% si on bouge, 0.2% si on est immobile
            CoutEnergie = if (NouvelleX /= X) or (NouvelleY /= Y) -> 1.0; true -> 0.2 end,
            NouvelleBatterie = max(0.0, Bat - CoutEnergie),
            
            %% si batterie < 20%, le drone retourne a la base automatiquement
            NouveauStatus = if NouvelleBatterie < 20.0 -> returning; true -> StatusActuel end,
            %% nb: la base c'est le centre (300, 300)
            NouvelleCible = if NouveauStatus == returning -> {300.0, 300.0}; true -> {TX, TY} end,
            
            %% on envoie notre nouvelle position au controleur
            drones_controller:update_state(Id, {NouvelleX, NouvelleY}, NouvelleBatterie),
            {noreply, State#{pos => {NouvelleX, NouvelleY}, target => NouvelleCible, battery => NouvelleBatterie, status => NouveauStatus}}
    end.

%% FONCTION DE DEPLACEMENT
%% nb: fait avancer de 10 pixels vers la cible, ou s'arrete si on est assez proche


move(Current, Target) ->
    Difference = Target - Current,
    if
        abs(Difference) < 10.0 -> Target;  %% on est arrive
        Difference > 0 -> Current + 10.0;   %% on avance vers la droite/bas
        true -> Current - 10.0               %% on avance vers la gauche/haut
    end.

%% callbacks obligatoires mais pas utilises
terminate(_Reason, _State) -> ok.
code_change(_Old, State, _Extra) -> {ok, State}.