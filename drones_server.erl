-module(drones_server).
-export([start/0, init/0]).

start() ->
    Pid = spawn(drones_server, init, []),
    register(drones_server, Pid),
    {ok, Pid}.

init() ->
    io:format("SERVEUR DRONE : Démarré (~p)~n", [self()]),
    %% On enregistre ce serveur comme un drone ID 999 pour la GUI
    drones_controller:register_drone(self(), 999),
    loop([300.0, 300.0, 0.0]). %% On commence au centre (300, 300)

loop([X, Y, Z] = CurrentPos) ->
    %% On envoie la position à la GUI
    drones_controller:update_state(999, {X, Y}, 100.0),
    
    receive
        {msg, From, Command} ->
            NewPos = case Command of
                avancer -> [X, Y-20.0, Z];   %% On augmente le pas à 20 pixels
                reculer -> [X, Y+20.0, Z];
                gauche  -> [X-20.0, Y, Z];
                droite  -> [X+20.0, Y, Z];
                fin     -> io:format("Atterrissage~n"), [X,Y,Z];
                _       -> CurrentPos
            end,
            
            io:format("SERVEUR : ~p -> Position : ~p~n", [Command, NewPos]),
            From ! {reply, NewPos},
            
            if Command == fin -> ok;
               true -> loop(NewPos)
            end
    end.
