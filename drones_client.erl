-module(drones_client).
-export([start/0, start/1]).

%% c'est le module client, genre l'interface utilisateur dans le terminal
%% on se connecte au serveur et on peut envoyer des ordres aux drones

%% demarre le client avec l'adresse par defaut du serveur
start() ->
    start('serveur@127.0.0.1').

%% demarre le client en se connectant a un noeud serveur specifique
start(ServerNode) ->
    case net_adm:ping(ServerNode) of
        pong ->
            %% pong = le serveur repond, on est connecte!
            io:format("~n[Client] Connecte au serveur : ~p~n", [ServerNode]),
            boucle_principale(ServerNode);
        pang ->
            %% pang = pas de reponse, le serveur est pas la
            io:format("~n[Erreur] Impossible de joindre ~p.~n", [ServerNode]),
            io:format("Verifie l'adresse IP et le cookie.~n")
    end.

%% la boucle principale: affiche le menu, lit le choix, execute, recommence
boucle_principale(Node) ->
    afficher_menu_principal(),
    Choix = lire_entier("Votre choix : "),
    Continuer = traiter_choix(Choix, Node),
    if
        Continuer -> boucle_principale(Node);
        true -> io:format("Deconnexion du client.~n")
    end.

%% affiche le menu principal dans le terminal
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


%% TRAITEMENT DES CHOIX DU MENU
%% nb: chaque choix retourne true pour continuer ou false pour quitter


%% choix 1: assigner des coordonnees
%% nb: maintenant on peut choisir un drone specifique ou tous les drones!
traiter_choix(1, Node) ->
    io:format("~n--- ASSIGNATION DE COORDONNEES ---~n"),
    io:format("0. Envoyer a TOUS les drones~n"),
    io:format("Ou entrez l'ID d'un drone specifique (ex: 1, 2, 3...)~n"),
    DroneChoix = lire_entier("Choix du drone (0 = tous) : "),
    X = lire_entier("Entrez X : "),
    Y = lire_entier("Entrez Y : "),
    if
        DroneChoix == 0 ->
            %% on envoie a tous les drones
            rpc:cast(Node, drones_controller, broadcast_mission, [X, Y, Node]),
            io:format("Coordonnees (~p, ~p) envoyees a TOUS les drones!~n", [X, Y]);
        DroneChoix > 0 ->
            %% on envoie a un drone specifique
            rpc:cast(Node, drones_controller, send_mission_to_drone, [DroneChoix, X, Y]),
            io:format("Coordonnees (~p, ~p) envoyees au drone #~p!~n", [X, Y, DroneChoix]);
        true ->
            io:format("Choix invalide, retour au menu.~n")
    end,
    true;

%% choix 2: exploration aleatoire
traiter_choix(2, Node) ->
    rpc:cast(Node, drones_controller, random_exploration, []),
    io:format("Ordre envoye : Les drones s'eparpillent !~n"),
    true;

%% choix 3: arret d'urgence
traiter_choix(3, Node) ->
    rpc:cast(Node, drones_controller, emergency_stop, []),
    io:format("Ordre d'arret d'urgence envoye !~n"),
    true;

%% choix 4: formations geometriques
traiter_choix(4, Node) ->
    formations_menu(Node),
    true;

%% choix 5: afficher le rapport et proposer la recharge
traiter_choix(5, Node) ->
    %% on recupere l'etat de tous les drones depuis le serveur
    State = rpc:call(Node, drones_controller, get_all_states, []),
    DronesMap = maps:get(drones, State, #{}),
    io:format("~nRAPPORT FLOTTE (~p drones) :~n", [maps:size(DronesMap)]),
    afficher_drones_rec(maps:to_list(DronesMap)),
    
    %% on propose de recharger les drones
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

%% choix 0: quitter
traiter_choix(0, _Node) ->
    false;

%% choix invalide
traiter_choix(_, _Node) ->
    io:format("Choix invalide.~n"),
    true.

%% sous-menu pour choisir une formation
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

%% 
%% FONCTIONS UTILITAIRES
%% 

%% lit un entier depuis le terminal
%% nb: string:to_integer retourne {Nombre, Reste} ou error
lire_entier(Prompt) ->
    Ligne = io:get_line(Prompt),
    LignePropre = string:trim(Ligne),
    case string:to_integer(LignePropre) of
        {Entier, _Reste} when is_integer(Entier) -> Entier;
        _ -> -1  %% si c'est pas un nombre valide, on retourne -1
    end.

%% affiche la liste des drones de facon recursive
%% nb: c'est comme un foreach mais en erlang
afficher_drones_rec([]) -> ok;
afficher_drones_rec([{Id, Data} | Reste]) ->
    {X, Y} = maps:get(pos, Data),
    Bat = maps:get(battery, Data),
    io:format("   - Drone #~p -> Position: [~p, ~p] | Batterie: ~p%~n", [Id, trunc(X), trunc(Y), trunc(Bat)]),
    afficher_drones_rec(Reste).