-module(testsuite).

-export([
    init/0,
    spawn_clients/1,
    auto_spawn_clients/1,
    report/0,
    run_all/0,
    test_case1/0,
    test_case1/1,
    test_case2/1,
    tmp_test/0,
    connect_clients/2,
    account_login_clients/1,
    char_login_clients/1,
    start_play_clients/1
    ]).

-include("report.hrl").

-define(TEST_CASE1_RUNTIME, 60000).

run_all() ->
    test_case1().

init() ->
    case lists:member(test_clients, ets:all()) of
        true ->
            pass;
        false ->
            ets:new(test_clients, [named_table])
    end.

tmp_test() ->
    Host = "10.0.0.30",
    init(),
    RunTime = 60000,
    io:format("Spawning clients...~n"),
    ClientList = spawn_clients(100),
    io:format("Connecting clients...~n"),
    connect_clients(ClientList, Host),
    io:format("Account login clients...~n"),
    account_login_clients(ClientList),
    io:format("Character login clients...~n"),
    char_login_clients(ClientList),
    %Start = now(),
    io:format("Start playing clients...~n"),
    start_play_clients(ClientList),
    io:format("Running test for ~p seconds, please wait...~n", 
        [RunTime/1000]),
    timer:sleep(RunTime),
    report(),
    exit_clients(ClientList).


test_case1() ->
    test_case1("localhost").

test_case1(Host) ->
    io:format("Running testcase 1.~n"),
    init(),
    RunTime = ?TEST_CASE1_RUNTIME,
    io:format("Spawning clients...~n"),
    ClientList = spawn_clients(10000),
    io:format("Connecting clients...~n"),
    connect_clients(ClientList, Host),
    io:format("Account login clients...~n"),
    account_login_clients(ClientList),
    io:format("Character login clients...~n"),
    char_login_clients(ClientList),
    %Start = now(),
    io:format("Start playing clients...~n"),
    start_play_clients(ClientList),
    io:format("Running test for ~p seconds, please wait...~n", 
        [RunTime/1000]),
    timer:sleep(RunTime),
    report().

test_case2(Host) ->
    io:format("Running testcase 2.~n"),
    init(),
    RunTime = ?TEST_CASE1_RUNTIME,
    io:format("Spawning clients...~n"),
    ClientList = spawn_clients(10),
    io:format("Connecting clients...~n"),
    connect_clients(ClientList, Host),
    io:format("Account login clients...~n"),
    account_login_clients(ClientList),
    io:format("Character login clients...~n"),
    char_login_clients(ClientList),
    %Start = now(),
    io:format("Start playing clients...~n"),
    start_play_clients(ClientList),
    io:format("Running test for ~p seconds, please wait...~n", 
        [RunTime/1000]),
    timer:sleep(RunTime),
    report().


auto_spawn_clients(Nr) ->
    auto_spawn_clients(Nr, []).

auto_spawn_clients(0, Acc) ->
    Acc;

auto_spawn_clients(Nr, Acc) ->
    Pid = client:auto_start(),
    auto_spawn_clients(Nr - 1, Acc ++ [Pid]).

spawn_clients(Nr) ->
    spawn_clients(Nr, []).

spawn_clients(0, Acc) ->
    Acc;

spawn_clients(Nr, Acc) ->
    Pid = client:start(),
    ets:insert(test_clients, {Pid, Nr}),
    spawn_clients(Nr - 1, Acc ++ [Pid]).

connect_clients([], _Host) ->
    done;

connect_clients([ClientPid | Tail], Host) ->
    client:connect(ClientPid, Host),
    connect_clients(Tail, Host).


account_login_clients([]) ->
    done;

account_login_clients([ClientPid | Tail]) ->
    client:account_login(ClientPid),
    account_login_clients(Tail).

char_login_clients(List) ->
    char_login_clients(List, 1, length(List)).

char_login_clients([], _Acc, _Max) ->
    done;

char_login_clients([ClientPid | Tail], Acc, Max) ->
    client:char_login(ClientPid),
    io:format("~p/~p logged in.~n", [Acc, Max]),
    char_login_clients(Tail, Acc + 1, Max).

start_play_clients([]) ->
    done;

start_play_clients([ClientPid | Tail]) ->
    client:start_play(ClientPid),
    start_play_clients(Tail).

report() ->
    io:format("Gathering data...~n", []),
    {YearStr, MonthStr, DayStr, HourStr, MinuteStr, SecondStr} = 
        get_calendar_time(),
    FileName = 
        YearStr ++ "_" ++
        MonthStr ++ "_" ++
        DayStr ++ "_" ++
        HourStr ++ "_" ++
        MinuteStr ++ "_" ++
        SecondStr ++ ".report",
    {ok, File} = file:open(FileName, [write]),
    io:format("Writing report to file: ~p.~n", 
        [filename:absname(FileName)]),
    report(ets:first(test_clients), #report{}, 0, File).

report('$end_of_table', Report, NrClients, File) ->
    ets:delete_all_objects(test_clients),
    {YearStr, MonthStr, DayStr, HourStr, MinuteStr, SecondStr} = 
        get_calendar_time(),
    file:write(File,
        "========== REPORT ==========\n"
        "Time: " ++ YearStr ++ "-" ++ MonthStr ++ "-" ++ DayStr ++ " " ++
        HourStr ++ ":" ++ MinuteStr ++ ":" ++ SecondStr ++ "\n\n" ++
        "Number of clients: " ++ integer_to_list(NrClients) ++ "\n" ++
        "Total commands sent: " ++ 
            integer_to_list(Report#report.cmds_sent) ++ "\n" ++
        "Total bytes sent: " ++
            bytes_to_list(Report#report.bytes_sent, bytes) ++ " bytes " ++
            bytes_to_list(Report#report.bytes_sent, kilobytes) ++ 
            " kilobytes " ++ 
            bytes_to_list(Report#report.bytes_sent, megabytes) ++ 
            " megabytes\n" ++
        "Total bytes received: " ++
            bytes_to_list(Report#report.bytes_recv, bytes) ++ " bytes "++ 
            bytes_to_list(Report#report.bytes_recv, kilobytes) ++ 
            " kilobytes "++ 
            bytes_to_list(Report#report.bytes_recv, megabytes) ++ 
            " megabytes\n"),
    file:close(File);

report(ClientPid, Report, NrClients, File) ->
    ClientReport = client:report(ClientPid),
    file:write(File,
        "=== Client " ++ integer_to_list(NrClients) ++ " ===\n" ++
        "Commands sent: " ++ 
            integer_to_list(ClientReport#report.cmds_sent) ++ "\n" ++
        "Commands received: " ++ 
            integer_to_list(ClientReport#report.cmds_recv) ++ "\n" ++
        "Bytes sent: " ++
            bytes_to_list(ClientReport#report.bytes_sent, bytes) ++ 
            " bytes " ++
            bytes_to_list(ClientReport#report.bytes_sent, kilobytes) ++ 
            " kilobytes " ++ 
            bytes_to_list(ClientReport#report.bytes_sent, megabytes) ++ 
            " megabytes\n" ++
        "Bytes received: " ++
            bytes_to_list(ClientReport#report.bytes_recv, bytes) ++ 
            " bytes "++ 
            bytes_to_list(ClientReport#report.bytes_recv, kilobytes) ++ 
            " kilobytes "++ 
            bytes_to_list(ClientReport#report.bytes_recv, megabytes) ++ 
            " megabytes\n\n"),
    NewReport = #report{
        cmds_sent = Report#report.cmds_sent +  
            ClientReport#report.cmds_sent,
        cmds_recv = Report#report.cmds_recv +  
            ClientReport#report.cmds_sent,
        bytes_sent = Report#report.bytes_sent + 
            ClientReport#report.bytes_sent,
        bytes_recv = Report#report.bytes_recv + 
            ClientReport#report.bytes_recv},   
    report(ets:next(test_clients, ClientPid), NewReport, NrClients + 1,
        File).


get_calendar_time() ->
    {{Year, Month, Day}, {Hour, Minute, Second}} = calendar:local_time(),
    YearStr = integer_to_list(Year),
    MonthStr = integer_to_list(Month),
    DayStr = integer_to_list(Day),
    HourStr = integer_to_list(Hour),
    MinuteStr = integer_to_list(Minute),
    SecondStr = integer_to_list(Second),
    {YearStr, MonthStr, DayStr, HourStr, MinuteStr, SecondStr}.

bytes_to_list(Bytes, bytes) ->
    bytes_to_list(Bytes, 1);

bytes_to_list(Bytes, kilobytes) ->
    bytes_to_list(Bytes / 1024, 2);

bytes_to_list(Bytes, megabytes) ->
    bytes_to_list(Bytes / 1048576, 4);

bytes_to_list(Bytes, _Precision) when is_integer(Bytes) ->
    integer_to_list(Bytes);

bytes_to_list(Bytes, Precision) when is_float(Bytes) ->
    io_lib:format("~."++integer_to_list(Precision) ++ "f", [Bytes]).

exit_clients([]) ->
    done;

exit_clients([Pid | Tail]) ->
    exit(Pid, normal),
    exit_clients(Tail).

