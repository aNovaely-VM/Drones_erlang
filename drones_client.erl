-module(drones_client).
-export([start/0]).

start() ->
    io:format("~n====== MENU CONTRÔLEUR ======~n"),
    io:format("1 - Lancer une mission aléatoire (Enchères)~n"),
    io:format("2 - Voir l'état de la flotte~n"),
    loop().

loop() ->
    case io:read("Choix: ") of
        {ok, 1} -> 
            ServerNode = get_server_node(),
            X = rand:uniform(500), Y = rand:uniform(500),
            rpc:cast(ServerNode, drones_controller, broadcast_mission, [X, Y]),
            io:format("Mission envoyée !~n"),
            loop();
        {ok, 2} ->
            ServerNode = get_server_node(),
            State = rpc:call(ServerNode, drones_controller, get_all_states, []),
            io:format("État global : ~p~n", [State]),
            loop();
        _ -> loop()
    end.

get_server_node() ->
    NodeName = atom_to_list(node()),
    [_Name, Host] = string:tokens(NodeName, "@"),
    list_to_atom("server_node@" ++ Host).
