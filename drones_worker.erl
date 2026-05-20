-module(drones_worker).
-behaviour(gen_server).

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
    timer:send_interval(1000, tick),
    {ok, #{id => Id, pos => {X, Y}, target => {X, Y}, battery => 100.0, status => idle}}.

handle_call(_Request, _From, State) -> {reply, ok, State}.

handle_cast({eval_mission, MX, MY}, State = #{pos := {X, Y}, status := Status, battery := Bat}) ->
    Dist = math:sqrt(math:pow(MX - X, 2) + math:pow(MY - Y, 2)),
    case {Status, Bat > 30.0} of
        {idle, true} when Dist < 300.0 ->
            {noreply, State#{target => {MX, MY}, status => mission}};
        _ -> 
            {noreply, State}
    end;
handle_cast(_Msg, State) -> {noreply, State}.

handle_info(tick, State = #{id := Id, pos := {X, Y}, target := {TX, TY}, battery := Bat}) ->
    NewX = move(X, TX),
    NewY = move(Y, TY),
    NewBat = Bat - (if (X /= TX) -> 1.0; true -> 0.2 end),
    
    Status = if NewBat < 20.0 -> returning; true -> maps:get(status, State) end,
    Target = if Status == returning -> {100.0, 100.0}; true -> {TX, TY} end,

    drones_controller:update_state(Id, {NewX, NewY}, NewBat),

    if NewBat =< 0 -> exit(battery_exhausted);
       true -> {noreply, State#{pos => {NewX, NewY}, battery => NewBat, target => Target, status => Status}}
    end;
handle_info(_Info, State) -> {noreply, State}.

terminate(_Reason, _State) -> ok.
code_change(_OldVsn, State, _Extra) -> {ok, State}.

move(Curr, Dest) when abs(Dest - Curr) < 5.0 -> Dest;
move(Curr, Dest) when Dest > Curr -> Curr + 5.0;
move(Curr, Dest) -> Curr - 5.0.