%% -------------------------------------------------------------------
%%
%%  eleveldb: Erlang Wrapper for LevelDB (http://code.google.com/p/leveldb/)
%%
%% Copyright (c) 2010 Basho Technologies, Inc. All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------
-module(eleveldb).

-export([open/2,
         close/1,
         get/3,
         put/4,
         delete/3,
         write/3,
         fold/4,
         fold_keys/4,
         status/2,
         destroy/2,
         repair/2,
         is_empty/1]).

-export([option_types/1,
         validate_options/2]).

-export([iterator/2,
         iterator_move/2,
         iterator_close/1]).

-on_load(init/0).

-ifdef(TEST).
-ifdef(EQC).
-include_lib("eqc/include/eqc.hrl").
-define(QC_OUT(P),
        eqc:on_output(fun(Str, Args) -> io:format(user, Str, Args) end, P)).
-endif.
-include_lib("eunit/include/eunit.hrl").
-endif.

-define(ASYNC_NIF_CALL(Fun, Args),
        begin
            NIFRef = erlang:make_ref(),
            case erlang:apply(Fun, [NIFRef|Args]) of
                {ok, Metric} ->
                    erlang:bump_reductions(Metric),
                    receive
                        {NIFRef, Reply} ->
                            Reply
                    end;
                Other -> Other
            end
        end).


-spec init() -> ok | {error, any()}.
init() ->
    SoName = case code:priv_dir(?MODULE) of
                 {error, bad_name} ->
                     case code:which(?MODULE) of
                         Filename when is_list(Filename) ->
                             filename:join([filename:dirname(Filename),"../priv", "eleveldb"]);
                         _ ->
                             filename:join("../priv", "eleveldb")
                     end;
                 Dir ->
                     filename:join(Dir, "eleveldb")
             end,
    erlang:load_nif(SoName, 0).

-type open_options() :: [{create_if_missing, boolean()} |
                         {error_if_exists, boolean()} |
                         {write_buffer_size, pos_integer()} |
                         {max_open_files, pos_integer()} |
                         {block_size, pos_integer()} |                  %% DEPRECATED
                         {sst_block_size, pos_integer()} |
                         {block_restart_interval, pos_integer()} |
                         {cache_size, pos_integer()} |
                         {paranoid_checks, boolean()} |
                         {compression, boolean()} |
                         {use_bloomfilter, boolean() | pos_integer()}].

-type read_options() :: [{verify_checksums, boolean()} |
                         {fill_cache, boolean()}].

-type write_options() :: [{sync, boolean()}].

-type write_actions() :: [{put, Key::binary(), Value::binary()} |
                          {delete, Key::binary()} |
                          clear].

-type repair_options() :: [].

-type iterator_action() :: first | last | next | prev | binary().

-opaque db_ref() :: binary().

-opaque itr_ref() :: binary().

-spec open(string(), open_options()) -> {ok, db_ref()} | {error, any()}.
open(Name, Opts) ->
    ?ASYNC_NIF_CALL(fun open_int/3, [Name, Opts]).

open_nif(_Ref, _Name, _Opts) ->
    erlang:nif_error({error, not_loaded}).

-spec close(db_ref()) -> ok | {error, any()}.
close(DbRef) ->
    ?ASYNC_NIF_CALL(fun close_int/2, [DbRef]).


close_nif(_Ref, _DbRef) ->
    erlang:nif_error({error, not_loaded}).

-spec get(db_ref(), binary(), read_options()) -> {ok, binary()} | not_found | {error, any()}.
get(DbRef, Key, Opts) ->
    ?ASYNC_NIF_CALL(fun get_int/4, [DbRef, Key, Opts]).

get_nif(_Ref, _DbRef, _Key, _Opts) ->
    erlang:nif_error({error, not_loaded}).

-spec put(db_ref(), binary(), binary(), write_options()) -> ok | {error, any()}.
put(DbRef, Key, Value, Opts) ->
    put_int(DbRef, Key, Value, Opts).

put_int(DbRef, Key, Value, Opts) ->
    write(DbRef, [{put, Key, Value}], Opts).

-spec delete(db_ref(), binary(), write_options()) -> ok | {error, any()}.
delete(DbRef, Key, Opts) ->
    delete_int(DbRef, Key, Opts).

delete_int(DbRef, Key, Opts) ->
    write(DbRef, [{delete, Key}], Opts).

-spec write(db_ref(), write_actions(), write_options()) -> ok | {error, any()}.
write(DbRef, Updates, Opts) ->
    ?ASYNC_NIF_CALL(fun write_int/4, [DbRef, Updates, Opts]).


write_nif(_Ref, _DbRef, _Updates, _Opts) ->
    erlang:nif_error({error, not_loaded}).

-spec iterator(db_ref(), read_options()) -> {ok, itr_ref()}.
iterator(DbRef, Opts) ->
    ?ASYNC_NIF_CALL(fun iterator_int/3, [DbRef, Opts]).


iterator_nif(_Ref, _DbRef, _Opts) ->
    erlang:nif_error({error, not_loaded}).

-spec iterator(db_ref(), read_options(), keys_only) -> {ok, itr_ref()}.
iterator(DbRef, Opts, keys_only) ->
    ?ASYNC_NIF_CALL(fun iterator_int/4, [DbRef, Opts, keys_only]).

iterator_nif(_Ref, _DbRef, _Opts, keys_only) ->
    erlang:nif_error({error, not_loaded}).

-spec iterator_move(itr_ref(), iterator_action()) -> {ok, Key::binary(), Value::binary()} |
                                                     {ok, Key::binary()} |
                                                     {error, invalid_iterator} |
                                                     {error, iterator_closed}.
iterator_move(IRef, Loc) ->
    ?ASYNC_NIF_CALL(fun iterator_move_int/3, [IRef, Loc]).

iterator_move_nif(_Ref, _IRef, _Loc) ->
    erlang:nif_error({error, not_loaded}).


-spec iterator_close(itr_ref()) -> ok.
iterator_close(IRef) ->
    ?ASYNC_NIF_CALL(fun iterator_close_int/2, [IRef]).

iterator_close_nif(_Ref, _IRef) ->
    erlang:nif_error({error, not_loaded}).

-type fold_fun() :: fun(({Key::binary(), Value::binary()}, any()) -> any()).

%% Fold over the keys and values in the database
%% will throw an exception if the database is closed while the fold runs
-spec fold(db_ref(), fold_fun(), any(), read_options()) -> any().
fold(DbRef, Fun, Acc0, Opts) ->
    {ok, Itr} = iterator(DbRef, Opts),
    do_fold(Itr, Fun, Acc0, Opts).

-type fold_keys_fun() :: fun((Key::binary(), any()) -> any()).

%% Fold over the keys in the database
%% will throw an exception if the database is closed while the fold runs
-spec fold_keys(db_ref(), fold_keys_fun(), any(), read_options()) -> any().
fold_keys(DbRef, Fun, Acc0, Opts) ->
    {ok, Itr} = iterator(DbRef, Opts, keys_only),
    do_fold(Itr, Fun, Acc0, Opts).

-spec status(db_ref(), Key::binary()) -> {ok, binary()} | error.
status(DbRef, Key) ->
    ?ASYNC_NIF_CALL(fun status_int/3, [DbRef, Key]).

status_nif(_Ref, _DbRef, _Key) ->
    erlang:nif_error({error, not_loaded}).

-spec destroy(string(), open_options()) -> ok | {error, any()}.
destroy(Name, Opts) ->
    ?ASYNC_NIF_CALL(fun destroy_int/3, [Name, Opts]).

-spec destroy_nif(reference(), string(), open_options()) -> ok | {error, any()}.
destroy_nif(_Ref, _Name, _Opts) ->
    erlang:nif_error({erlang, not_loaded}).

-spec repair(string(), repair_options()) -> ok | {error, any()}.
repair(Name, Opts) ->
    ?ASYNC_NIF_CALL(fun repair_int/3, [Name, Opts]).

-spec repair_nif(reference(), string(), repair_options()) -> ok | {error, any()}.
repair_nif(_Ref, _Name, _Opts) ->
    erlang:nif_error({erlang, not_loaded}).

-spec is_empty(db_ref()) -> boolean().
is_empty(DbRef) ->
    ?ASYNC_NIF_CALL(fun is_empty_int/2, [DbRef]).

-spec is_empty_nif(reference(), db_ref()) -> boolean().
is_empty_nif(_Ref, _DbRef) ->
    erlang:nif_error({error, not_loaded}).

option_types(open) ->
    [{create_if_missing, bool},
     {error_if_exists, bool},
     {write_buffer_size, integer},
     {max_open_files, integer},
     {block_size, integer},                            %% DEPRECATED
     {sst_block_size, integer},
     {block_restart_interval, integer},
     {cache_size, integer},
     {paranoid_checks, bool},
     {compression, bool},
     {use_bloomfilter, any}];
option_types(read) ->
    [{verify_checksums, bool},
     {fill_cache, bool}];
option_types(write) ->
     [{sync, bool}].

-spec validate_options(open | read | write, [{atom(), any()}]) ->
                              {[{atom(), any()}], [{atom(), any()}]}.
validate_options(Type, Opts) ->
    Types = option_types(Type),
    lists:partition(fun({K, V}) ->
                            KType = lists:keyfind(K, 1, Types),
                            validate_type(KType, V)
                    end, Opts).



%% ===================================================================
%% Internal functions
%% ===================================================================

do_fold(Itr, Fun, Acc0, Opts) ->
    try
        %% Extract {first_key, binary()} and seek to that key as a starting
        %% point for the iteration. The folding function should use throw if it
        %% wishes to terminate before the end of the fold.
        Start = proplists:get_value(first_key, Opts, first),
        true = is_binary(Start) or (Start == first),
        fold_loop(iterator_move(Itr, Start), Itr, Fun, Acc0)
    after
        iterator_close(Itr)
    end.

fold_loop({error, iterator_closed}, _Itr, _Fun, Acc0) ->
    throw({iterator_closed, Acc0});
fold_loop({error, invalid_iterator}, _Itr, _Fun, Acc0) ->
    Acc0;
fold_loop({ok, K}, Itr, Fun, Acc0) ->
    Acc = Fun(K, Acc0),
    fold_loop(iterator_move(Itr, next), Itr, Fun, Acc);
fold_loop({ok, K, V}, Itr, Fun, Acc0) ->
    Acc = Fun({K, V}, Acc0),
    fold_loop(iterator_move(Itr, next), Itr, Fun, Acc).

validate_type({_Key, bool}, true)                            -> true;
validate_type({_Key, bool}, false)                           -> true;
validate_type({_Key, integer}, Value) when is_integer(Value) -> true;
validate_type({_Key, any}, _Value)                           -> true;
validate_type(_, _)                                          -> false.


%% ===================================================================
%% EUnit tests
%% ===================================================================
-ifdef(TEST).

open_test() ->
    os:cmd("rm -rf /tmp/eleveldb.open.test"),
    {ok, Ref} = open("/tmp/eleveldb.open.test", [{create_if_missing, true}]),
    ok = ?MODULE:put(Ref, <<"abc">>, <<"123">>, []),
    {ok, <<"123">>} = ?MODULE:get(Ref, <<"abc">>, []),
    not_found = ?MODULE:get(Ref, <<"def">>, []).

fold_test() ->
    os:cmd("rm -rf /tmp/eleveldb.fold.test"),
    {ok, Ref} = open("/tmp/eleveldb.fold.test", [{create_if_missing, true}]),
    ok = ?MODULE:put(Ref, <<"def">>, <<"456">>, []),
    ok = ?MODULE:put(Ref, <<"abc">>, <<"123">>, []),
    ok = ?MODULE:put(Ref, <<"hij">>, <<"789">>, []),
    [{<<"abc">>, <<"123">>},
     {<<"def">>, <<"456">>},
     {<<"hij">>, <<"789">>}] = lists:reverse(fold(Ref, fun({K, V}, Acc) -> [{K, V} | Acc] end,
                                                  [], [])).

fold_keys_test() ->
    os:cmd("rm -rf /tmp/eleveldb.fold.keys.test"),
    {ok, Ref} = open("/tmp/eleveldb.fold.keys.test", [{create_if_missing, true}]),
    ok = ?MODULE:put(Ref, <<"def">>, <<"456">>, []),
    ok = ?MODULE:put(Ref, <<"abc">>, <<"123">>, []),
    ok = ?MODULE:put(Ref, <<"hij">>, <<"789">>, []),
    [<<"abc">>, <<"def">>, <<"hij">>] = lists:reverse(fold_keys(Ref,
                                                                fun(K, Acc) -> [K | Acc] end,
                                                                [], [])).

fold_from_key_test() ->
    os:cmd("rm -rf /tmp/eleveldb.fold.fromkeys.test"),
    {ok, Ref} = open("/tmp/eleveldb.fromfold.keys.test", [{create_if_missing, true}]),
    ok = ?MODULE:put(Ref, <<"def">>, <<"456">>, []),
    ok = ?MODULE:put(Ref, <<"abc">>, <<"123">>, []),
    ok = ?MODULE:put(Ref, <<"hij">>, <<"789">>, []),
    [<<"def">>, <<"hij">>] = lists:reverse(fold_keys(Ref,
                                                     fun(K, Acc) -> [K | Acc] end,
                                                     [], [{first_key, <<"d">>}])).

destroy_test() ->
    os:cmd("rm -rf /tmp/eleveldb.destroy.test"),
    {ok, Ref} = open("/tmp/eleveldb.destroy.test", [{create_if_missing, true}]),
    ok = ?MODULE:put(Ref, <<"def">>, <<"456">>, []),
    {ok, <<"456">>} = ?MODULE:get(Ref, <<"def">>, []),
    close(Ref),
    ok = ?MODULE:destroy("/tmp/eleveldb.destroy.test", []),
    {error, {db_open, _}} = open("/tmp/eleveldb.destroy.test", [{error_if_exists, true}]).

compression_test() ->
    CompressibleData = list_to_binary([0 || _X <- lists:seq(1,50000)]),
    os:cmd("rm -rf /tmp/eleveldb.compress.0 /tmp/eleveldb.compress.1"),
    {ok, Ref0} = open("/tmp/eleveldb.compress.0", [{write_buffer_size, 5},
                                                   {create_if_missing, true},
                                                   {compression, false}]),
    [ok = ?MODULE:put(Ref0, <<I:64/unsigned>>, CompressibleData, [{sync, true}]) ||
        I <- lists:seq(1,10)],
    {ok, Ref1} = open("/tmp/eleveldb.compress.1", [{write_buffer_size, 5},
                                                   {create_if_missing, true},
                                                   {compression, true}]),
    [ok = ?MODULE:put(Ref1, <<I:64/unsigned>>, CompressibleData, [{sync, true}]) ||
        I <- lists:seq(1,10)],
        %% Check both of the LOG files created to see if the compression option was correctly
        %% passed down
        MatchCompressOption =
                fun(File, Expected) ->
                                {ok, Contents} = file:read_file(File),
                                case re:run(Contents, "Options.compression: " ++ Expected) of
                                        {match, _} -> match;
                                        nomatch -> nomatch
                                end
                end,
        Log0Option = MatchCompressOption("/tmp/eleveldb.compress.0/LOG", "0"),
        Log1Option = MatchCompressOption("/tmp/eleveldb.compress.1/LOG", "1"),
        ?assert(Log0Option =:= match andalso Log1Option =:= match).


close_test() ->
    os:cmd("rm -rf /tmp/eleveldb.close.test"),
    {ok, Ref} = open("/tmp/eleveldb.close.test", [{create_if_missing, true}]),
    ?assertEqual(ok, close(Ref)),
    ?assertEqual({error, einval}, close(Ref)).

close_fold_test() ->
    os:cmd("rm -rf /tmp/eleveldb.close_fold.test"),
    {ok, Ref} = open("/tmp/eleveldb.close_fold.test", [{create_if_missing, true}]),
    ok = eleveldb:put(Ref, <<"k">>,<<"v">>,[]),
    ?assertException(throw, {iterator_closed, ok}, % ok is returned by close as the acc
                     eleveldb:fold(Ref, fun(_,A) -> eleveldb:close(Ref) end, undefined, [])).

-ifdef(EQC).

qc(P) ->
    ?assert(eqc:quickcheck(?QC_OUT(P))).

keys() ->
    eqc_gen:non_empty(list(eqc_gen:non_empty(binary()))).

values() ->
    eqc_gen:non_empty(list(binary())).

ops(Keys, Values) ->
    {oneof([put, delete]), oneof(Keys), oneof(Values)}.

apply_kv_ops([], _DbRef, Acc0) ->
    Acc0;
apply_kv_ops([{put, K, V} | Rest], Ref, Acc0) ->
    ok = eleveldb:put(Ref, K, V, []),
    apply_kv_ops(Rest, Ref, orddict:store(K, V, Acc0));
apply_kv_ops([{delete, K, _} | Rest], Ref, Acc0) ->
    ok = eleveldb:delete(Ref, K, []),
    apply_kv_ops(Rest, Ref, orddict:store(K, deleted, Acc0)).

prop_put_delete() ->
    ?LET({Keys, Values}, {keys(), values()},
         ?FORALL(Ops, eqc_gen:non_empty(list(ops(Keys, Values))),
                 begin
                     ?cmd("rm -rf /tmp/eleveldb.putdelete.qc"),
                     {ok, Ref} = eleveldb:open("/tmp/eleveldb.putdelete.qc",
                                                [{create_if_missing, true}]),
                     Model = apply_kv_ops(Ops, Ref, []),

                     %% Valdiate that all deleted values return not_found
                     F = fun({K, deleted}) ->
                                 ?assertEqual(not_found, eleveldb:get(Ref, K, []));
                            ({K, V}) ->
                                 ?assertEqual({ok, V}, eleveldb:get(Ref, K, []))
                         end,
                     lists:map(F, Model),

                     %% Validate that a fold returns sorted values
                     Actual = lists:reverse(fold(Ref, fun({K, V}, Acc) -> [{K, V} | Acc] end,
                                                 [], [])),
                     ?assertEqual([{K, V} || {K, V} <- Model, V /= deleted],
                                  Actual),
                     true
                 end)).

prop_put_delete_test_() ->
    {timeout, 3*60, fun() -> qc(prop_put_delete()) end}.



-endif.

-endif.
