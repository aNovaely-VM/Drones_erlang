-module(drones_server).
-export([start/0, init/0]).


%% nb: ce module c'est l'ancien serveur de drone unique
%% il est moins utilise maintenant qu'on a le systeme avec plusieurs drones
%% mais on le garde au cas ou


%% demarre le serveur et l'enregistre sous le nom drones_server
start() ->
    Pid = spawn(drones_server, init, []),
    register(drones_server, Pid),
    {ok, Pid}.

%% initialisation: on s'enregistre comme drone 999 (c'est un peu le drone "special")
init() ->
    io:format("SERVEUR DRONE : Demarre (~p)~n", [self()]),
    %% on s'enregistre aupres du controleur avec l'ID 999
    drones_controller:register_drone(self(), 999),
    %% on commence au centre de la fenetre (300, 300)
    loop([300.0, 300.0, 0.0]).

%% boucle principale: attend des messages et bouge le drone
loop([X, Y, Z] = CurrentPos) ->
    %% on envoie notre position a la gui
    drones_controller:update_state(999, {X, Y}, 100.0),
    
    receive
        {msg, From, Command} ->
            %% on calcule la nouvelle position selon la commande
            %% nb: on bouge de 20 pixels a chaque commande
            NewPos = case Command of
                avancer -> [X, Y-20.0, Z];
                reculer -> [X, Y+20.0, Z];
                gauche  -> [X-20.0, Y, Z];
                droite  -> [X+20.0, Y, Z];
                fin     -> io:format("Atterrissage~n"), [X,Y,Z];
                _       -> CurrentPos
            end,
            
            io:format("SERVEUR : ~p -> Position : ~p~n", [Command, NewPos]),
            From ! {reply, NewPos},
            
            %% si c'est pas la commande fin, on continue la boucle
            if Command == fin -> ok;
               true -> loop(NewPos)
            end
    end.