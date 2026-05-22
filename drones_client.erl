-module(drones_client).
-export([start/0, start/1]).

start() ->
    start('serveur@127.0.0.1').

start(ServerNode) ->
    case net_adm:ping(ServerNode) of
        pong ->
            io:format("~n[Client] Connecte au serveur : ~p~n", [ServerNode]),
            boucle_principale(ServerNode);
        pang ->
            io:format("~n[Erreur] Impossible de joindre ~p.~n", [ServerNode]),
            io:format("Verifie l'adresse IP et le cookie.~n")
    end.

boucle_principale(Node) ->
    afficher_menu_principal(),
    Choix = lire_entier("Votre choix : "),
    Continuer = traiter_choix(Choix, Node),
    if
        Continuer -> boucle_principale(Node);
        true -> io:format("Deconnexion du client.~n")
    end.

afficher_menu_principal() ->
    io:format("~n=========================================~n"),
    io:format("        INTERFACE DE PILOTAGE ESSAIM     ~n"),
    io:format("=========================================~n"),
    io:format("1. Assigner des coordonnees (X, Y)~n"),
    io:format("2. Mode exploration aleatoire~n"),
    io:format("3. ARRET D'URGENCE (Stop global)~n"),
    io:format("4. Choisir une formation geometrique~n"),
    io:format("5. Afficher le rapport d'etat complet et Recharger~n"),
    io:format("0. Quitter le terminal~n"),
    io:format("=========================================~n").

traiter_choix(1, Node) ->
    X = lire_entier("Entrez X : "),
    Y = lire_entier("Entrez Y : "),
    rpc:cast(Node, drones_controller, broadcast_mission, [X, Y, Node]),
    true;

traiter_choix(2, Node) ->
    rpc:cast(Node, drones_controller, random_exploration, []),
    io:format("Ordre envoye : Les drones s'eparpillent !~n"),
    true;

traiter_choix(3, Node) ->
    rpc:cast(Node, drones_controller, emergency_stop, []),
    io:format("Ordre d'arret d'urgence envoye !~n"),
    true;

traiter_choix(4, Node) ->
    formations_menu(Node),
    true;

traiter_choix(5, Node) ->
    State = rpc:call(Node, drones_controller, get_all_states, []),
    DronesMap = maps:get(drones, State, #{}),
    io:format("~nRAPPORT FLOTTE (~p drones) :~n", [maps:size(DronesMap)]),
    afficher_drones_rec(maps:to_list(DronesMap)),
    
    io:format("~nVoulez-vous recharger les drones actuellement a la base ? (1 = Oui, 0 = Non)~n"),
    ChoixRecharge = lire_entier("Choix : "),
    if
        ChoixRecharge == 1 ->
            rpc:cast(Node, drones_controller, recharge_base, []),
            io:format("Ordre de recharge massive envoye a la base !~n");
        true ->
            io:format("Passage de la recharge.~n")
    end,
    true;

traiter_choix(0, _Node) ->
    false;

traiter_choix(_, _Node) ->
    io:format("Choix invalide.~n"),
    true.

formations_menu(Node) ->
    io:format("~n--- CHOIX DE LA FORMATION ---~n"),
    io:format("1. Carre regulier~n"),
    io:format("2. Escadrille Chasse (V)~n"),
    io:format("3. Cercle parfait~n"),
    io:format("0. Retour~n"),
    Choix = lire_entier("Choix formation : "),
    if
        Choix == 1 -> 
            rpc:cast(Node, drones_controller, apply_formation, [carre]),
            io:format("Formation Carre envoyee !~n");
        Choix == 2 -> 
            rpc:cast(Node, drones_controller, apply_formation, [chasse]),
            io:format("Formation Chasse envoyee !~n");
        Choix == 3 -> 
            rpc:cast(Node, drones_controller, apply_formation, [cercle]),
            io:format("Formation Cercle envoyee !~n");
        Choix == 0 -> 
            ok;
        true -> 
            io:format("Saisie invalide.~n"),
            formations_menu(Node)
    end.

lire_entier(Prompt) ->
    Ligne = io:get_line(Prompt),
    LignePropre = string:trim(Ligne),
    %% Le pattern matching ignore maintenant intelligemment ce qu'il y a après le chiffre
    case string:to_integer(LignePropre) of
        {Entier, _Reste} when is_integer(Entier) -> Entier;
        _ -> -1
    end.

afficher_drones_rec([]) -> ok;
afficher_drones_rec([{Id, Data} | Reste]) ->
    {X, Y} = maps:get(pos, Data),
    Bat = maps:get(battery, Data),
    io:format("   - Drone #~p -> Position: [~p, ~p] | Batterie: ~p%~n", [Id, trunc(X), trunc(Y), trunc(Bat)]),
    afficher_drones_rec(Reste).