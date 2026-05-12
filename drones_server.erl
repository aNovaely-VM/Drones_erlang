-module(drones_server).
-export([start/0, init/0]).

start() ->
    Pid = spawn(drones_server, init, []),
    register(drones_server, Pid),
    {ok, Pid}.

init() ->
    io:format("SERVEUR DRONE : Démarré (~p)~n", [self()]),
    loop([0, 0, 0]).

print_formation([X,Y]) -> io:format("[~p]~n[~p]~n[~p]~n",[build_formation(0,0,[X,Y]),build_formation(1,0,[X,Y]),build_formation(2,0,[X,Y])]).

build_formation(N,M,[X,Y]) when N == Y, M == X, N < 3, M < 3 -> ['*'|build_formation(N,M+1,[X,Y])];
build_formation(N,M,_) when N>=3 ; M>=3 -> [];
build_formation(N,M,[X,Y]) -> ['.'|build_formation(N,M+1,[X,Y])].

loop([X, Y, Z] = CurrentPos) ->
	print_formation([X,Z]),
    receive
        {msg, From, avancer} when (X<2) ->
            NewPos = [X+1, Y, Z],
            io:format("SERVEUR DRONE : Avance -> Position : ~p~n", [NewPos]),
            From ! {reply, NewPos},
			
            loop(NewPos);
		{msg, From, avancer} when (X>1) ->
            io:format("SERVEUR DRONE : Impossible d'avancer plus~n~n"),
            From ! {reply, CurrentPos},
            loop(CurrentPos);
        {msg, From, reculer} when (X>0) ->
            NewPos = [X-1, Y, Z],
            io:format("SERVEUR DRONE : Recule -> Position : ~p~n~n", [NewPos]),
            From ! {reply, NewPos},
            loop(NewPos);
		{msg, From, reculer} when (X<1) ->
            io:format("SERVEUR DRONE : Impossible de reculer plus~n~n"),
            From ! {reply, CurrentPos},
            loop(CurrentPos);
        {msg, From, gauche} ->
            NewPos = [X, Y-1, Z],
            io:format("SERVEUR DRONE : Gauche -> Position : ~p~n~n", [NewPos]),
            From ! {reply, NewPos},
            loop(NewPos);
        {msg, From, droite} ->
            NewPos = [X, Y+1, Z],
            io:format("SERVEUR DRONE : Droite -> Position : ~p~n~n", [NewPos]),
            From ! {reply, NewPos},
            loop(NewPos);
        {msg, From, monter} when (Z<2) ->
            NewPos = [X, Y, Z+1],
            io:format("SERVEUR DRONE : Monte -> Position : ~p~n~n", [NewPos]),
            From ! {reply, NewPos},
            loop(NewPos);
		{msg, From, monter} when (Z>1) ->
            io:format("SERVEUR DRONE : Impossible de monter plus~n~n"),
            From ! {reply, CurrentPos},
            loop(CurrentPos);
        {msg, From, descendre} when (Z>0) ->
            NewPos = [X, Y, Z-1],
            io:format("SERVEUR DRONE : Descend -> Position : ~p~n~n", [NewPos]),
            From ! {reply, NewPos},
            loop(NewPos);
		{msg, From, avancer} when (Z<1) ->
            io:format("SERVEUR DRONE : Impossible de descendre plus~n~n"),
            From ! {reply, CurrentPos},
            loop(CurrentPos);
        {msg, From, fin} ->
            io:format("SERVEUR DRONE : Atterrissage. Position finale : ~p~n", [CurrentPos]),
            From ! {reply, CurrentPos},
            ok;
        _ ->
            io:format("SERVEUR DRONE : Message inconnu reçu.~n"),
            loop(CurrentPos)
    end.
