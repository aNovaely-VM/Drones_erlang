-module(drones_sup).
-behaviour(supervisor).

-export([start_link/0, init/1, start_drone/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%% Fonction pour ajouter un drone dynamiquement au cours du projet
start_drone(Id) ->
    ChildSpec = #{id => {drone, Id},
                  start => {drones_worker, start_link, [Id]},
                  restart => transient,
                  type => worker},
    supervisor:start_child(?MODULE, ChildSpec).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 5},
    
    Children = [
        #{id => drones_controller,
          start => {drones_controller, start_link, []}},
        #{id => drones_gui,
          start => {drones_gui, start_link, []}}
    ],
    {ok, {SupFlags, Children}}.