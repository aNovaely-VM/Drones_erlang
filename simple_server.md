-module(simple_server).
 
-export([start/0, stop/0, send/1, init/0]).
 
start() ->
  Pid = spawn( simple_server, init, []),
  register(simple_server, Pid),
  {ok, Pid}.
 
init() ->
  io:format("Serveur démarré (~p)~n", [self()]),
  loop().
               
loop() ->
  receive
   {msg, From, Text} ->
     io:format("Message reçu de ~p : ~s~n", [From, Text]),
     From ! {reply, ok},
     loop();
   stop ->
     io:format("Arrêt du serveur~n"),
     ok
  end.
 
send(Text) ->
  {simple_server, 'node1@127.0.0.1'} ! {msg, self(), Text},
    receive
  {reply, ok} ->
     ok
   after 20000 ->
   timeout
  end.
 
stop() ->
  {simple_server, 'node1@127.0.0.1'} ! stop.