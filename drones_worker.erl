-module(drones_worker).
-behaviour(gen_server).

%% C'est cette variable que tu peux modifier pour augmenter ou reduire 
%% les pourcentages gagnes a chaque seconde passée a la base.
-define(VITESSE_RECHARGE, 15.0).

-export([start_link/1, evaluate_mission/3]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

start_link(Id) ->
    gen_server:start_link(?MODULE, [Id], []).

evaluate_mission(Pid, X, Y) -> 
    gen_server:cast(Pid, {eval_mission, float(X), float(Y)}).

init([Id]) ->
    X = float(rand:uniform(500)), 
    Y = float(rand:uniform(500)),
    drones_controller:register_drone(self(), Id),
    timer:send_interval(150, tick),
    {ok, #{id => Id, pos => {X, Y}, target => {X, Y}, battery => 500.0, status => idle}}.

handle_call(_Request, _From, State) -> {reply, ok, State}.

handle_cast({eval_mission, MX, MY}, State = #{status := StatusActuel}) ->
    if
        StatusActuel /= recharging ->
            {noreply, State#{target => {MX, MY}, status => mission}};
        true ->
            {noreply, State}
    end;

handle_cast(stop, State = #{pos := {X, Y}}) ->
    {noreply, State#{status => idle, target => {X, Y}}};

handle_cast(recharge, State) ->
    {noreply, State#{status => recharging}};

handle_cast(_Msg, State) -> 
    {noreply, State}.

handle_info(tick, State = #{id := Id, pos := {X, Y}, target := {TX, TY}, battery := Bat, status := StatusActuel}) ->
    if
        StatusActuel == recharging ->
            NouvelleBatterie = min(100.0, Bat + ?VITESSE_RECHARGE),
            NouveauStatus = if NouvelleBatterie >= 100.0 -> idle; true -> recharging end,
            drones_controller:update_state(Id, {X, Y}, NouvelleBatterie),
            {noreply, State#{battery => NouvelleBatterie, status => NouveauStatus}};
            
        true ->
            NouvelleX = move(X, TX),
            NouvelleY = move(Y, TY),
            
            CoutEnergie = if (NouvelleX /= TX) or (NouvelleY /= TY) -> 1.0; true -> 0.2 end,
            NouvelleBatterie = max(0.0, Bat - CoutEnergie),
            
            NouveauStatus = if NouvelleBatterie < 20.0 -> returning; true -> StatusActuel end,
            NouvelleCible = if NouveauStatus == returning -> {300.0, 300.0}; true -> {TX, TY} end,
            
            drones_controller:update_state(Id, {NouvelleX, NouvelleY}, NouvelleBatterie),
            {noreply, State#{pos => {NouvelleX, NouvelleY}, target => NouvelleCible, battery => NouvelleBatterie, status => NouveauStatus}}
    end.

move(Current, Target) ->
    Difference = Target - Current,
    if
        abs(Difference) < 10.0 -> Target;
        Difference > 0 -> Current + 10.0;
        true -> Current - 10.0
    end.

terminate(_Reason, _State) -> ok.
code_change(_Old, State, _Extra) -> {ok, State}.