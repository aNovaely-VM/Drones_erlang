-module(drones_client).
-export([start/0, start/1]).

start() ->
    %% Par défaut, connexion en local sur la même machine
    start('serveur@127.0.0.1').

start(ServerNode) ->
    case net_adm:ping(ServerNode) of
        pong ->
            io:format("~n[Client] Connecte au serveur de drones : ~p~n", [ServerNode]),
            boucle_principale(ServerNode);
        pang ->
            io:format("~n[Erreur] Impossible de joindre le serveur ~p.~n", [ServerNode]),
            io:format("Verifie l'adresse IP et le cookie réseau.~n")
    end.

boucle_principale(Node) ->
    afficher_menu_principal(),
    case io:fread("👉 Votre choix : ", "~d") of
        {ok, [Choix]} ->
            Continuer = traiter_choix(Choix, Node),
            if 
                Continuer -> boucle_principale(Node);
                true -> io:format("Deconnexion du client.~n")
            end;
        _ ->
            io:get_line(""), %% Nettoyer le tampon en cas de mauvaise saisie
            boucle_principale(Node)
    end.

afficher_menu_principal() ->
    io:format("~n=========================================~n"),
    io:format("        INTERFACE DE PILOTAGE ESSAIM     ~n"),
    io:format("=========================================~n"),
    io:format("1.  Assigner des coordonnées (X, Y)~n"),
    io:format("2.  Mode exploration aléatoire~n"),
    io:format("3.  ARRET D'URGENCE (Stop global)~n"),
    io:format("4.  Choisir une formation géométrique~n"),
    io:format("5.  Afficher le rapport d'état complet~n"),
    io:format("0.  Quitter le terminal~n"),
    io:format("=========================================~n").

traiter_choix(1, Node) ->
    {ok, [X]} = io:fread("Entrez X : ", "~d"),
    {ok, [Y]} = io:fread("Entrez Y : ", "~d"),
    rpc:cast(Node, drones_controller, broadcast_mission, [X, Y, Node]),
    true;
traiter_choix(2, Node) ->
    X = rand:uniform(400) + 50,
    Y = rand:uniform(400) + 50,
    rpc:cast(Node, drones_controller, broadcast_mission, [X, Y, Node]),
    true;
traiter_choix(3, Node) ->
    rpc:cast(Node, drones_controller, emergency_stop, []),
    true;
traiter_choix(4, Node) ->
    formations_menu(Node),
    true;
traiter_choix(5, Node) ->
    State = rpc:call(Node, drones_controller, get_all_states, []),
    DronesMap = maps:get(drones, State, #{}),
    io:format("~n📊 RAPPORT FLOTTE :~n"),
    afficher_drones_rec(maps:to_list(DronesMap)),
    true;
traiter_choix(0, _Node) ->
    false;
traiter_choix(_, _Node) ->
    io:format("Choix invalide.~n"),
    true.

formations_menu(Node) ->
    io:format("~n--- CHOIX DE LA FORMATION ---~n"),
    io:format("1.  Carré régulier~n"),
    io:format("2.  Escadrille Chasse (V)~n"),
    io:format("3.  Cercle parfait~n"),
    io:format("0. ↩  Retour~n"),
    case io:fread("👉 Choix : ", "~d") of
        {ok, [1]} -> rpc:cast(Node, drones_controller, apply_formation, [carre]);
        {ok, [2]} -> rpc:cast(Node, drones_controller, apply_formation, [chasse]);
        {ok, [3]} -> rpc:cast(Node, drones_controller, apply_formation, [cercle]);
        _ -> ok
    end.

afficher_drones_rec([]) -> ok;
afficher_drones_rec([{Id, Data} | Reste]) ->
    {X, Y} = maps:get(pos, Data),
    Bat = maps:get(battery, Data),
    io:format("   - Drone #~p -> Position: [~p, ~p] | Batterie: ~p%~n", [Id, trunc(X), trunc(Y), trunc(Bat)]),
    afficher_drones_rec(Reste).