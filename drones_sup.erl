-module(drones_sup).
-behaviour(supervisor).

%% ============================================================================
%% nb: c'est le superviseur, il gere le demarrage et le redemarrage des processus
%% si un processus plante, le superviseur peut le relancer automatiquement
%% ============================================================================

-export([start_link/0, init/1, start_drone/1]).

%% demarre le superviseur et l'enregistre sous le nom drones_sup
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%% fonction pour ajouter un nouveau drone pendant que le programme tourne
%% nb: c'est ca qu'on appelle quand on fait drones_sup:start_drone(1)
start_drone(Id) ->
    ChildSpec = #{id => {drone, Id},
                  start => {drones_worker, start_link, [Id]},
                  restart => transient,  %% transient = redemarrer si crash anormal
                  type => worker},
    supervisor:start_child(?MODULE, ChildSpec).

%% initialisation du superviseur
init([]) ->
    %% strategie one_for_one: si un enfant plante, on relance juste celui-la
    %% intensity 10, period 5: max 10 restarts en 5 secondes avant d'abandonner
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 5},
    
    %% les enfants qui demarrent automatiquement avec le superviseur
    %% nb: le controleur et la gui demarrent en premier, les drones on les ajoute apres
    Children = [
        #{id => drones_controller,
          start => {drones_controller, start_link, []}},
        #{id => drones_gui,
          start => {drones_gui, start_link, []}}
    ],
    {ok, {SupFlags, Children}}.