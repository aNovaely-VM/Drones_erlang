-module(drones_client).
-export([start/0]).

start() ->
    client_loop().

client_loop() ->
    afficher_menu(),
    Choice = lire_choix(),
    case Choice of
        7 ->
            io:format("CLIENT DRONE : Atterrissage demandé.~n"),
            send_command(fin);
        _ when Choice >= 1 andalso Choice =< 6 ->
            Command = case Choice of
                1 -> avancer;
                2 -> reculer;
                3 -> gauche;
                4 -> droite;
                5 -> monter;
                6 -> descendre
            end,
            io:format("CLIENT DRONE : Commande ~p envoyée.~n", [Command]),
            send_command(Command),
            client_loop();
        _ ->
            io:format("CLIENT DRONE : Choix invalide. Veuillez réessayer.~n"),
            client_loop()
    end.

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

send_command(Command) ->
    %% On récupère le nom de la machine actuelle (ex: 'MatthiasDell')
    NodeName = atom_to_list(node()),
    [_Name, Host] = string:tokens(NodeName, "@"),
    
    %% On construit le nom du serveur sur la même machine
    ServerNode = list_to_atom("server_node@" ++ Host),
    
    case net_adm:ping(ServerNode) of
        pong ->
            {drones_server, ServerNode} ! {msg, self(), Command},
            receive
                {reply, NewPos} ->
                    io:format("CLIENT DRONE : Nouvelle position reçue : ~p~n", [NewPos])
            after 5000 ->
                io:format("CLIENT DRONE : Timeout en attente de réponse du serveur.~n")
            end;
        _ ->
            io:format("CLIENT DRONE : Impossible de contacter le serveur sur le nœud ~p.~n", [ServerNode]),
            io:format("Assurez-vous d'avoir lancé le serveur avec : erl -sname server_node~n")
    end.
