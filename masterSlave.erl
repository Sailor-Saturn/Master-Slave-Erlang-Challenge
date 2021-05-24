% Trabalho feito por Vera Dias 1160941
-module(masterSlave).

-export([spawnSensors/0,start/0,init/0,masterSlaveCommunication/1,fireStarted/3,
    deallocate/3,stopWorkSensor/2,findSensorId/2,startSensor/1]).

%Criacao de sensores atraves de um metodo
spawnSensors() ->
    io:format("Starting sensor 1"),
    spawn(masterSlave, startSensor, [1]),
    io:format("Starting sensor 2"),
    spawn(masterSlave, startSensor, [2]),
    io:format("Starting sensor 3"),
    spawn(masterSlave, startSensor, [3]),
    io:format("Starting sensor 4"),
    spawn(masterSlave, startSensor, [4]).

startSensor(Id)->
    % Comunicar que houve um fogo
    master ! {self(),Id,fire},
    receive
        {reply,{error, process_already_working}} -> io:format("This process was already working!~n");
        {reply,{ok,Id}} ->
            io:format("The sensor with the id ~w has reported a fire ~n",[Id]),
            timer:sleep(10000),
            io:format("The sensor with the id ~w has ended the fire, terminating process... ~n",[Id]),
            % Comunicar que quer parar o processo
            master ! {self(),Id,stopWorking},
            receive
				{reply,ok} -> io:format("Sensor terminated... ~n")
			end
    end.


% Metodo que começa o programa
start() ->
    register(master,spawn(fun init/0)).

init() ->
    % É necessária usar esta função para fazer trap dos erros mais a frente.
    process_flag(trap_exit, true),
    % A função master tem uma lista de sensores a trabalhar, lista de sensores que nao estao a trabalhar e o ultimo alarme tudo vazio ou sem nada
    masterSlaveCommunication({[],[],0}).

masterSlaveCommunication(Communications) ->
    receive 
        % Um fogo começou
        {From,Id,fire} ->
            {NewCommunications, Reply} = fireStarted(From,Id,Communications),
            case Reply of 
                {error,_} ->
                    From! {reply,Reply};
                _ ->
                    From! {reply,Reply},
                    masterSlaveCommunication(NewCommunications)
            end;
        % O sensor quer parar de trabalhar
        {From,Id,stopWorking} ->
            unlink(From),
            NewCommunications = deallocate(Communications, Id,From),
            From! {reply,ok},
            masterSlaveCommunication(NewCommunications);
        %Visitar a lista
        {From,peek} ->
            From! Communications,
            masterSlaveCommunication(Communications);
        % O sensor termina normalmente
        {'EXIT', _, normal} -> masterSlaveCommunication(Communications);
        {'EXIT', From, _} ->
            Id = find(From, Communications),
            NewCommunications = deallocate(Communications, Id,From),
            masterSlaveCommunication(NewCommunications)
end.

% Para comunicar que um fogo comecou a condição de paragem é se este sensor ja esteja a trabalhar
fireStarted(_,Id,{[{_,Id}|_],_,_}) -> {[],{error,process_already_working}};
% Colocar como ultimo fogo o id deste sensor
fireStarted(From,Id,{Working,NotWorking,_}) -> {{[{From,Id}|Working],NotWorking,Id},{ok,Id}}.

deallocate({Working,NotWorking,FireId},Id,From) ->{stopWorkSensor(Working,Id),[{From,Id}|NotWorking],FireId}.

% Encontrar o sensor e apaga-lo da lista
stopWorkSensor([],_) -> [];
% Encontrou-se o Id
stopWorkSensor([Id|T],Id) -> T;
stopWorkSensor([H|T],Id) -> [H|stopWorkSensor(T,Id)].

%Encontrar Sensor
find(From, {Working, _,_}) ->
    findSensorId(From, Working).

findSensorId(From, [{From,Id} | _]) -> Id;
findSensorId(From, [_ | T]) -> findSensorId(From, T).