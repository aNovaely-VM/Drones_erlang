-module(drones_server).
-export([start/0, init/0]).

start() ->
    Pid = spawn(drones_server, init, []),
    register(drones_server, Pid),
    {ok, Pid}.

init() ->
    io:format("SERVEUR DRONE : Démarré (~p)~n", [self()]),
    loop([0, 0, 0]).

loop([X, Y, Z] = CurrentPos) ->
    receive
        {msg, From, avancer} ->
            NewPos = [X+1, Y, Z],
            io:format("SERVEUR DRONE : Avance -> Position : ~p~n", [NewPos]),
            From ! {reply, NewPos},
            loop(NewPos);
        {msg, From, reculer} ->
            NewPos = [X-1, Y, Z],
            io:format("SERVEUR DRONE : Recule -> Position : ~p~n", [NewPos]),
            From ! {reply, NewPos},
            loop(NewPos);
        {msg, From, gauche} ->
            NewPos = [X, Y-1, Z],
            io:format("SERVEUR DRONE : Gauche -> Position : ~p~n", [NewPos]),
            From ! {reply, NewPos},
            loop(NewPos);
        {msg, From, droite} ->
            NewPos = [X, Y+1, Z],
            io:format("SERVEUR DRONE : Droite -> Position : ~p~n", [NewPos]),
            From ! {reply, NewPos},
            loop(NewPos);
        {msg, From, monter} ->
            NewPos = [X, Y, Z+1],
            io:format("SERVEUR DRONE : Monte -> Position : ~p~n", [NewPos]),
            From ! {reply, NewPos},
            loop(NewPos);
        {msg, From, descendre} ->
            NewPos = [X, Y, Z-1],
            io:format("SERVEUR DRONE : Descend -> Position : ~p~n", [NewPos]),
            From ! {reply, NewPos},
            loop(NewPos);
        {msg, From, fin} ->
            io:format("SERVEUR DRONE : Atterrissage. Position finale : ~p~n", [CurrentPos]),
            From ! {reply, CurrentPos},
            ok;
        _ ->
            io:format("SERVEUR DRONE : Message inconnu reçu.~n"),
            loop(CurrentPos)
    end.
