# Drones_erlang

Equipe : ARDEVOL-CARRAT Matthias ; PRAYEZ Tim ; CANTERA Nino ; EKO'O MEKUU Roche Kevin
Thématique : Le client représente un opérateur humain qui pilote un drone via un menu de commandes directionnelles (avancer, reculer, gauche, droite, monter, descendre). Le serveur représente la centrale de contrôle du drone, qui reçoit les ordres et maintient en temps réel la position du drone dans l'espace sous forme de coordonnées [X, Y, Z]. L'objectif final est de simuler le pilotage d'un essaim de drones utilisés lors de spectacles de festivals, où chaque drone peut se déplacer de façon précise pour former des figures dans le ciel.


erl -name serveur@127.0.0.1 -setcookie essaim_drones
c(drones_controller), c(drones_gui), c(drones_worker), c(drones_sup).
drones_sup:start_link().
drones_sup:start_drone(1).
drones_sup:start_drone(2).
drones_sup:start_drone(3).

[drones_sup:start_drone(Id) || Id <- lists:seq(1, 20)].   ( 20 drones )



erl -name client@127.0.0.1 -setcookie essaim_drones
c(drones_client).
drones_client:start().