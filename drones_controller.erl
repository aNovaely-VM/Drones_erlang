-module(drones_controller).
-export([broadcast_mission/3, get_all_states/0, register_drone/2, update_state/3]).

-record(state, {drones = #{}, stations = []}).

%% Simple state to hold drone and station data
-persistent_term:put(drones_state, #state{}).

broadcast_mission(_X, _Y, _Node) ->
    io:format("Controller: Mission broadcasted to ~p, ~p~n", [_X, _Y]),
    ok.

get_all_states() ->
    #state{drones = Drones, stations = Stations} = persistent_term:get(drones_state),
    #{drones => Drones, stations => Stations}.

register_drone(Pid, Id) ->
    #state{drones = Drones} = persistent_term:get(drones_state),
    NewDrones = maps:put(Id, #{pid => Pid, pos => {0,0}, battery => 100}),
    persistent_term:put(drones_state, #state{drones = NewDrones}),
    io:format("Controller: Drone ~p registered with PID ~p~n", [Id, Pid]),
    ok.

update_state(Id, Pos, Battery) ->
    #state{drones = Drones} = persistent_term:get(drones_state),
    case maps:get(Id, Drones, undefined) of
        undefined ->
            io:format("Controller: Drone ~p not found for state update~n", [Id]);
        Drone ->
            UpdatedDrone = Drone#{pos => Pos, battery => Battery},
            NewDrones = maps:put(Id, UpdatedDrone, Drones),
            persistent_term:put(drones_state, #state{drones = NewDrones})
    end,
    ok.
