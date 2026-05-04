-module(drones).
-export([start/0, client/1]).

start() ->
    Pid = spawn(drones, client, [self()]),
    loop_receive(Pid, [0, 0, 0]).

loop_receive(Pid, [X, Y, Z]) ->
    receive
        {Pid, avancer} -> 
            NouvellePos = [X+1, Y, Z],                
            io:format("SERVEUR : Drone avance -> Position : ~p~n", [NouvellePos]),
            loop_receive(Pid, NouvellePos);
        {Pid, reculer} -> 
            NouvellePos = [X-1, Y, Z],
            io:format("SERVEUR : Drone recule -> Position : ~p~n", [NouvellePos]),
            loop_receive(Pid, NouvellePos);
		{Pid, gauche} -> 
            NouvellePos = [X, Y, Z-1],
            io:format("SERVEUR : Drone recule -> Position : ~p~n", [NouvellePos]),
            loop_receive(Pid, NouvellePos);
		{Pid, droite} -> 
            NouvellePos = [X, Y, Z+1],
            io:format("SERVEUR : Drone recule -> Position : ~p~n", [NouvellePos]),
            loop_receive(Pid, NouvellePos);
		{Pid, monter} -> 
            NouvellePos = [X, Y+1, Z],
            io:format("SERVEUR : Drone recule -> Position : ~p~n", [NouvellePos]),
            loop_receive(Pid, NouvellePos);
		{Pid, descendre} -> 
            NouvellePos = [X, Y-1, Z],
            io:format("SERVEUR : Drone recule -> Position : ~p~n", [NouvellePos]),
            loop_receive(Pid, NouvellePos);
        {Pid, fin}  -> io:format("SERVEUR : Drone atterrit. Position finale : ~p~n", [[X, Y, Z]])
    end.

client(Pid) ->
    afficher_menu(),
    Choice = lire_choix(),
    traiter_choix(Pid, Choice).

afficher_menu() ->
    io:format("~n====== MENU DRONE ======~n"),
    io:format("1 - Avancer~n"),
    io:format("2 - Reculer~n"),
    io:format("3 - Gauche~n"),
    io:format("4 - Droite~n"),
    io:format("5 - Monter~n"),
    io:format("6 - Descendre~n"),
    io:format("7 - Quitter~n"),
    io:format("========================~n").

lire_choix() ->
    case io:read("Votre choix : ") of
        {ok, Choix} -> Choix;
        eof -> io:format("lecture fin de fichier~n"), eof;
        {error, Reason} -> io:format("Erreur ~p~n", [Reason])
    end.

traiter_choix(P, 1) -> 
    io:format("CLIENT : Avancer~n"), 
    P ! {self(), avancer},   
    client(P);

traiter_choix(P, 2) -> 
    io:format("CLIENT : Reculer~n"), 
    P ! {self(), reculer},   
    client(P);

traiter_choix(P, 3) -> 
    io:format("CLIENT : Gauche~n"),
    P ! {self(), gauche},    
    client(P);

traiter_choix(P, 4) -> 
    io:format("CLIENT : Droite~n"), 
    P ! {self(), droite},    
    client(P);

traiter_choix(P, 5) -> 
    io:format("CLIENT : Monter~n"), 
    P ! {self(), monter},    
    client(P);

traiter_choix(P, 6) -> 
    io:format("CLIENT : Descendre~n"), 
    P ! {self(), descendre}, 
    client(P);

traiter_choix(P, 7) -> 
    io:format("CLIENT : Atterrissage~n"), 
    P ! {self(), fin};

traiter_choix(P, _) -> 
    io:format("Choix invalide~n"), 
    client(P).
