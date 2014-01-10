%%======================================================================
%%
%% Leo Manager
%%
%% Copyright (c) 2012-2013 Rakuten, Inc.
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
%% ---------------------------------------------------------------------
%% Leo Manager - Mnesia.
%% @doc
%% @end
%%======================================================================
-module(leo_manager_mnesia).

-author('Yosuke Hara').

-include("leo_manager.hrl").
-include_lib("leo_commons/include/leo_commons.hrl").
-include_lib("leo_logger/include/leo_logger.hrl").
-include_lib("leo_redundant_manager/include/leo_redundant_manager.hrl").
-include_lib("leo_s3_libs/include/leo_s3_libs.hrl").
-include_lib("stdlib/include/qlc.hrl").

%% API
-export([create_storage_nodes/2,
         create_gateway_nodes/2,
         create_rebalance_info/2,
         create_histories/2,
         create_available_commands/2,

         get_storage_nodes_all/0,
         get_storage_node_by_name/1,
         get_storage_nodes_by_status/1,
         get_gateway_nodes_all/0,
         get_gateway_node_by_name/1,
         get_rebalance_info_all/0,
         get_rebalance_info_by_node/1,
         get_histories_all/0,
         get_available_commands_all/0,
         get_available_command_by_name/1,

         update_storage_node_status/1,
         update_storage_node_status/2,
         update_gateway_node/1,
         update_rebalance_info/1,
         insert_history/1,
         insert_available_command/2,

         delete_storage_node/1,
         delete_gateway_node/1,

         delete_all/0,
         backup/1,
         restore/1,

         update_available_commands/1
        ]).


%%-----------------------------------------------------------------------
%% Create Table
%%-----------------------------------------------------------------------
%% @doc Create a table of storage-nodes
%%
-spec(create_storage_nodes(atom(), list()) ->
             ok).
create_storage_nodes(Mode, Nodes) ->
    mnesia:create_table(
      ?TBL_STORAGE_NODES,
      [{Mode, Nodes},
       {type, set},
       {record_name, node_state},
       {attributes, record_info(fields, node_state)},
       {user_properties,
        [{node,          {varchar,  undefined},  false, primary,   undefined, undefined, atom     },
         {state,         {varchar,  undefined},  false, undefined, undefined, undefined, atom     },
         {ring_hash_new, {varchar,  undefined},  false, undefined, undefined, undefined, undefined},
         {ring_hash_old, {varchar,  undefined},  false, undefined, undefined, undefined, undefined},
         {when_is,       {integer,  undefined},  false, undefined, undefined, undefined, integer  },
         {error,         {integer,  undefined},  false, undefined, undefined, undefined, integer  }
        ]}
      ]).


%% @doc Create a table of gateway-nodes
%%
-spec(create_gateway_nodes(atom(), list()) ->
             ok).
create_gateway_nodes(Mode, Nodes) ->
    mnesia:create_table(
      ?TBL_GATEWAY_NODES,
      [{Mode, Nodes},
       {type, set},
       {record_name, node_state},
       {attributes, record_info(fields, node_state)},
       {user_properties,
        [{node,          {varchar,  undefined},  false, primary,   undefined, undefined, atom     },
         {state,         {varchar,  undefined},  false, undefined, undefined, undefined, atom     },
         {ring_hash_new, {varchar,  undefined},  false, undefined, undefined, undefined, undefined},
         {ring_hash_old, {varchar,  undefined},  false, undefined, undefined, undefined, undefined},
         {when_is,       {integer,  undefined},  false, undefined, undefined, undefined, integer  },
         {error,         {integer,  undefined},  false, undefined, undefined, undefined, integer  }
        ]}
      ]).


%% @doc Create a table of rebalance-info
%%
-spec(create_rebalance_info(atom(), list()) ->
             ok).
create_rebalance_info(Mode, Nodes) ->
    mnesia:create_table(
      ?TBL_REBALANCE_INFO,
      [{Mode, Nodes},
       {type, set},
       {record_name, rebalance_info},
       {attributes, record_info(fields, rebalance_info)},
       {user_properties,
        [{vnode_id,         {integer,   undefined},  false, primary,   undefined, identity,  integer},
         {node,             {varchar,   undefined},  false, undefined, undefined, undefined, atom   },
         {total_of_objects, {integer,   undefined},  false, undefined, undefined, undefined, integer},
         {num_of_remains,   {integer,   undefined},  false, undifined, undefined, undefined, integer},
         {when_is,          {integer,   undefined},  false, undifined, undefined, undefined, integer}
        ]}
      ]).


create_histories(Mode, Nodes) ->
    mnesia:create_table(
      ?TBL_HISTORIES,
      [{Mode, Nodes},
       {type, set},
       {record_name, history},
       {attributes, record_info(fields, history)},
       {user_properties,
        [{id,      {integer,   undefined},  false, primary,   undefined, undefined, integer},
         {command, {varchar,   undefined},  false, undefined, undefined, identity,  string },
         {created, {integer,   undefined},  false, undifined, undefined, undefined, integer}
        ]}
      ]).


create_available_commands(Mode, Nodes) ->
    mnesia:create_table(
      ?TBL_AVAILABLE_CMDS,
      [{Mode, Nodes},
       {type, set},
       {record_name, cmd_state},
       {attributes, record_info(fields, cmd_state)},
       {user_properties,
        [{name,  {varchar,   undefined},  false, primary,   undefined, identity,  string },
         {help,  {varchar,   undefined},  false, undefined, undefined, identity,  string },
         {state, {boolean,   undefined},  false, undifined, undefined, undefined, boolean}
        ]}
      ]).


%%-----------------------------------------------------------------------
%% GET
%%-----------------------------------------------------------------------
%% @doc Retrieve all storage nodes
%%
-spec(get_storage_nodes_all() ->
             {ok, list()} | not_found | {error, any()}).
get_storage_nodes_all() ->
    Tbl = ?TBL_STORAGE_NODES,

    case catch mnesia:table_info(Tbl, all) of
        {'EXIT', _Cause} ->
            {error, ?ERROR_MNESIA_NOT_START};
        _ ->
            F = fun() ->
                        Q1 = qlc:q([X || X <- mnesia:table(Tbl)]),
                        Q2 = qlc:sort(Q1, [{order, ascending}]),
                        qlc:e(Q2)
                end,
            leo_mnesia:read(F)
    end.


%% @doc Retrieve a storage node by node-name
%%
-spec(get_storage_node_by_name(atom()) ->
             {ok, list()} | not_found | {error, any()}).
get_storage_node_by_name(Node) ->
    Tbl = ?TBL_STORAGE_NODES,

    case catch mnesia:table_info(Tbl, all) of
        {'EXIT', _Cause} ->
            {error, ?ERROR_MNESIA_NOT_START};
        _ ->
            F = fun() ->
                        Q1 = qlc:q([X || X <- mnesia:table(Tbl),
                                         X#node_state.node =:= Node]),
                        Q2 = qlc:sort(Q1, [{order, ascending}]),
                        qlc:e(Q2)
                end,
            leo_mnesia:read(F)
    end.


%% @doc Retrieve storage nodes by status
%%
-spec(get_storage_nodes_by_status(atom()) ->
             {ok, list()} | not_found | {error, any()}).
get_storage_nodes_by_status(Status) ->
    Tbl = ?TBL_STORAGE_NODES,

    case catch mnesia:table_info(Tbl, all) of
        {'EXIT', _Cause} ->
            {error, ?ERROR_MNESIA_NOT_START};
        _ ->
            F = fun() ->
                        Q1 = qlc:q([X || X <- mnesia:table(Tbl),
                                         X#node_state.state =:= Status]),
                        Q2 = qlc:sort(Q1, [{order, ascending}]),
                        qlc:e(Q2)
                end,
            leo_mnesia:read(F)
    end.


%% @doc Retrieve all gateway nodes
%%
-spec(get_gateway_nodes_all() ->
             {ok, list()} | not_found | {error, any()}).
get_gateway_nodes_all() ->
    Tbl = ?TBL_GATEWAY_NODES,

    case catch mnesia:table_info(Tbl, all) of
        {'EXIT', _Cause} ->
            {error, ?ERROR_MNESIA_NOT_START};
        _ ->
            F = fun() ->
                        Q1 = qlc:q([X || X <- mnesia:table(Tbl)]),
                        Q2 = qlc:sort(Q1, [{order, ascending}]),
                        qlc:e(Q2)
                end,
            leo_mnesia:read(F)
    end.


%% @doc Retrieve gateway node info by node-name
%%
-spec(get_gateway_node_by_name(atom()) ->
             {ok, list()} | not_found | {error, any()}).
get_gateway_node_by_name(Node) ->
    Tbl = ?TBL_GATEWAY_NODES,

    case catch mnesia:table_info(Tbl, all) of
        {'EXIT', _Cause} ->
            {error, ?ERROR_MNESIA_NOT_START};
        _ ->
            F = fun() ->
                        Q1 = qlc:q([X || X <- mnesia:table(Tbl),
                                         X#node_state.node =:= Node]),
                        Q2 = qlc:sort(Q1, [{order, ascending}]),
                        qlc:e(Q2)
                end,
            leo_mnesia:read(F)
    end.


%% @doc Retrieve rebalance info
%%
-spec(get_rebalance_info_all() ->
             {ok, list()} | not_found | {error, any()}).
get_rebalance_info_all() ->
    Tbl = ?TBL_REBALANCE_INFO,

    case catch mnesia:table_info(Tbl, all) of
        {'EXIT', _Cause} ->
            {error, ?ERROR_MNESIA_NOT_START};
        _ ->
            F = fun() ->
                        Q1 = qlc:q([X || X <- mnesia:table(?TBL_REBALANCE_INFO)]),
                        Q2 = qlc:sort(Q1, [{order, ascending}]),
                        qlc:e(Q2)
                end,
            leo_mnesia:read(F)
    end.


%% @doc Retrieve rebalance info by node
%%
-spec(get_rebalance_info_by_node(atom()) ->
             {ok, list()} | not_found | {error, any()}).
get_rebalance_info_by_node(Node) ->
    Tbl = ?TBL_REBALANCE_INFO,

    case catch mnesia:table_info(Tbl, all) of
        {'EXIT', _Cause} ->
            {error, ?ERROR_MNESIA_NOT_START};
        _ ->
            F = fun() ->
                        Q1 = qlc:q([X || X <- mnesia:table(Tbl),
                                         X#rebalance_info.node =:= Node]),
                        Q2 = qlc:sort(Q1, [{order, ascending}]),
                        qlc:e(Q2)
                end,
            leo_mnesia:read(F)
    end.


%% @doc Retrieve all histories
%%
-spec(get_histories_all() ->
             {ok, list()} | not_found | {error, any()}).
get_histories_all() ->
    Tbl = ?TBL_HISTORIES,

    case catch mnesia:table_info(Tbl, all) of
        {'EXIT', _Cause} ->
            {error, ?ERROR_MNESIA_NOT_START};
        _ ->
            F = fun() ->
                        Q1 = qlc:q([X || X <- mnesia:table(Tbl)]),
                        Q2 = qlc:sort(Q1, [{order, ascending}]),
                        qlc:e(Q2)
                end,
            leo_mnesia:read(F)
    end.


%% @doc Retrieve all available commands
%%
get_available_commands_all() ->
    Tbl = ?TBL_AVAILABLE_CMDS,

    case catch mnesia:table_info(Tbl, all) of
        {'EXIT', _Cause} ->
            {error, ?ERROR_MNESIA_NOT_START};
        _ ->
            F = fun() ->
                        Q1 = qlc:q([X || X <- mnesia:table(Tbl)]),
                        Q2 = qlc:sort(Q1, [{order, ascending}]),
                        qlc:e(Q2)
                end,
            leo_mnesia:read(F)
    end.


%% @doc Retrieve available command by name
%%
-spec(get_available_command_by_name(atom()) ->
             {ok, list()} | not_found | {error, any()}).
get_available_command_by_name(Name) ->
    Tbl = ?TBL_AVAILABLE_CMDS,

    case catch mnesia:table_info(Tbl, all) of
        {'EXIT', _Cause} ->
            {error, ?ERROR_MNESIA_NOT_START};
        _ ->
            F = fun() ->
                        Q1 = qlc:q([X || X <- mnesia:table(Tbl),
                                         X#cmd_state.name =:= Name]),
                        Q2 = qlc:sort(Q1, [{order, ascending}]),
                        qlc:e(Q2)
                end,
            leo_mnesia:read(F)
    end.


%%-----------------------------------------------------------------------
%% UPDATE
%%-----------------------------------------------------------------------
%% @doc Modify storage-node status
%%
-spec(update_storage_node_status(#node_state{}) ->
             ok | {error, any()}).
update_storage_node_status(NodeState) ->
    update_storage_node_status(update_state, NodeState).

-spec(update_storage_node_status(
        update|update_state|keep_state|update_chksum|increment_error|init_error, atom()) ->
             ok | {error, any()}).
update_storage_node_status(update, NodeState) ->
    Tbl = ?TBL_STORAGE_NODES,

    case catch mnesia:table_info(Tbl, all) of
        {'EXIT', _Cause} ->
            {error, ?ERROR_MNESIA_NOT_START};
        _ ->
            F = fun()-> mnesia:write(Tbl, NodeState, write) end,
            leo_mnesia:write(F)
    end;

update_storage_node_status(update_state, NodeState) ->
    #node_state{node = Node, state = State} = NodeState,
    case get_storage_node_by_name(Node) of
        {ok, [Cur|_]} ->
            update_storage_node_status(update, Cur#node_state{state = State});
        _ ->
            ok
    end;
update_storage_node_status(keep_state, NodeState) ->
    #node_state{node  = Node} = NodeState,
    case get_storage_node_by_name(Node) of
        {ok, [Cur|_]} ->
            update_storage_node_status(update, Cur);
        _ ->
            ok
    end;

update_storage_node_status(update_chksum, NodeState) ->
    #node_state{node  = Node,
                ring_hash_new = RingHash0,
                ring_hash_old = RingHash1} = NodeState,

    case get_storage_node_by_name(Node) of
        {ok, [Cur|_]} ->
            update_storage_node_status(
              update, Cur#node_state{ring_hash_new = RingHash0,
                                     ring_hash_old = RingHash1});
        _ ->
            ok
    end;

update_storage_node_status(increment_error, NodeState) ->
    #node_state{node = Node} = NodeState,
    case get_storage_node_by_name(Node) of
        {ok, [Cur|_]} ->
            update_storage_node_status(
              update, Cur#node_state{error = Cur#node_state.error + 1});
        _ ->
            ok
    end;

update_storage_node_status(init_error, NodeState) ->
    #node_state{node = Node} = NodeState,
    case get_storage_node_by_name(Node) of
        {ok, [Cur|_]} ->
            update_storage_node_status(
              update, Cur#node_state{error = 0});
        _ ->
            ok
    end;
update_storage_node_status(_, _) ->
    {error, badarg}.


%% @doc Modify gateway-node status
%%
-spec(update_gateway_node(#node_state{}) ->
             ok | {error, any()}).
update_gateway_node(NodeState) ->
    Tbl = ?TBL_GATEWAY_NODES,

    case catch mnesia:table_info(Tbl, all) of
        {'EXIT', _Cause} ->
            {error, ?ERROR_MNESIA_NOT_START};
        _ ->
            F = fun() -> mnesia:write(Tbl, NodeState, write) end,
            leo_mnesia:write(F)
    end.


%% @doc Modify rebalance-info
%%
-spec(update_rebalance_info(#rebalance_info{}) ->
             ok | {error, any()}).
update_rebalance_info(RebalanceInfo) ->
    Tbl = ?TBL_REBALANCE_INFO,

    case catch mnesia:table_info(Tbl, all) of
        {'EXIT', _Cause} ->
            {error, ?ERROR_MNESIA_NOT_START};
        _ ->
            F = fun()-> mnesia:write(Tbl, RebalanceInfo, write) end,
            leo_mnesia:write(F)
    end.


%% @doc Modify bucket-info
%%
-spec(insert_history(binary()) ->
             ok | {error, any()}).
insert_history(Command) ->
    [NewCommand|_] = string:tokens(binary_to_list(Command), "\r\n"),
    Id = case get_histories_all() of
             {ok, List} -> length(List) + 1;
             not_found  -> 1;
             {_, Cause} -> {error, Cause}
         end,

    case Id of
        {error, Reason} ->
            {error, Reason};
        _ ->
            Tbl = ?TBL_HISTORIES,

            case catch mnesia:table_info(Tbl, all) of
                {'EXIT', _Cause} ->
                    {error, ?ERROR_MNESIA_NOT_START};
                _ ->
                    F = fun() -> mnesia:write(?TBL_HISTORIES, #history{id = Id,
                                                                       command = NewCommand,
                                                                       created = leo_date:now()}, write) end,
                    leo_mnesia:write(F)
            end
    end.


insert_available_command(Command, Help) ->
    Tbl = ?TBL_AVAILABLE_CMDS,

    case catch mnesia:table_info(Tbl, all) of
        {'EXIT', _Cause} ->
            {error, ?ERROR_MNESIA_NOT_START};
        _ ->
            F = fun() -> mnesia:write(Tbl,
                                      #cmd_state{name = Command,
                                                 help = Help,
                                                 available = true}, write) end,
            leo_mnesia:write(F)
    end.


%%-----------------------------------------------------------------------
%% DELETE
%%-----------------------------------------------------------------------
%% @doc Remove storage-node by name
-spec(delete_storage_node(#node_state{}) ->
             ok | {error, any()}).
delete_storage_node(Node) when is_atom(Node) ->
    case get_storage_node_by_name(Node) of
        {ok, [NodeInfo|_]} ->
            delete_storage_node(NodeInfo);
        Error ->
            Error
    end;
delete_storage_node(Node) ->
    Tbl = ?TBL_STORAGE_NODES,

    case catch mnesia:table_info(Tbl, all) of
        {'EXIT', _Cause} ->
            {error, ?ERROR_MNESIA_NOT_START};
        _ ->
            F = fun() ->
                        mnesia:delete_object(Tbl, Node, write)
                end,
            leo_mnesia:delete(F)
    end.


%% @doc Remove gateway-node by name
-spec(delete_gateway_node(atom() | #node_state{}) ->
             ok | {error, any()}).
delete_gateway_node(Node) when is_atom(Node) ->
    case get_gateway_node_by_name(Node) of
        {ok, [NodeInfo|_]} ->
            delete_gateway_node(NodeInfo);
        Error ->
            Error
    end;
delete_gateway_node(Node) ->
    Tbl = ?TBL_GATEWAY_NODES,

    case catch mnesia:table_info(Tbl, all) of
        {'EXIT', _Cause} ->
            {error, ?ERROR_MNESIA_NOT_START};
        _ ->
            F = fun() ->
                        mnesia:delete_object(Tbl, Node, write)
                end,
            leo_mnesia:delete(F)
    end.

%% @doc Delete all tables
-spec(delete_all() ->
             ok | {error, any()}).
delete_all() ->
    {atomic, ok} = mnesia:delete_table(?TBL_HISTORIES),
    {atomic, ok} = mnesia:delete_table(?TBL_SYSTEM_CONF),
    {atomic, ok} = mnesia:delete_table(?TBL_GATEWAY_NODES),
    {atomic, ok} = mnesia:delete_table(?TBL_STORAGE_NODES),
    {atomic, ok} = mnesia:delete_table(?TBL_AVAILABLE_CMDS),
    {atomic, ok} = mnesia:delete_table(?TBL_REBALANCE_INFO),
    ok.

%% @doc Backup mnesia tables
-spec(backup(file:filename()) ->
             ok | {error, any()}).
backup(DstFilePath) ->
    {ok, Name, _Nodes} = mnesia:activate_checkpoint(
                           [{ram_overrides_dump, true},
                            {name, "backup"},
                            {max,[?TBL_HISTORIES,
                                  ?TBL_SYSTEM_CONF,
                                  ?TBL_GATEWAY_NODES,
                                  ?TBL_STORAGE_NODES,
                                  ?TBL_AVAILABLE_CMDS,
                                  ?TBL_REBALANCE_INFO,
                                  ?ENDPOINT_TABLE,
                                  ?AUTH_TABLE,
                                  ?BUCKET_TABLE,
                                  ?USERS_TABLE,
                                  ?USER_CREDENTIAL_TABLE]}]),
    try
        mnesia:backup_checkpoint(Name, DstFilePath)
    after
        mnesia:deactivate_checkpoint(Name)
    end.

%% @doc Restore mnesia tables
-spec(restore(file:filename()) ->
             ok | {error, any()}).
restore(DstFilePath) ->
    case mnesia:restore(DstFilePath, [{default_op, recreate_tables}]) of
        {atomic, RestoredTabs} ->
            validate_restored_tables(RestoredTabs);
        {aborted, Reason} ->
            {error, Reason}
    end.

%% @private validate restored tables
validate_restored_tables(RestoredTabs) ->
    TableSet = sets:new(),
    TableSet2 = sets:add_element(?TBL_HISTORIES, TableSet),
    TableSet3 = sets:add_element(?TBL_SYSTEM_CONF, TableSet2),
    TableSet4 = sets:add_element(?TBL_GATEWAY_NODES, TableSet3),
    TableSet5 = sets:add_element(?TBL_STORAGE_NODES, TableSet4),
    TableSet6 = sets:add_element(?TBL_AVAILABLE_CMDS, TableSet5),
    TableSet7 = sets:add_element(?TBL_REBALANCE_INFO, TableSet6),
    TableSet8 = sets:add_element(?ENDPOINT_TABLE, TableSet7),
    TableSet9 = sets:add_element(?AUTH_TABLE, TableSet8),
    TableSet10 = sets:add_element(?BUCKET_TABLE, TableSet9),
    TableSet11 = sets:add_element(?USERS_TABLE, TableSet10),
    TableSet12 = sets:add_element(?USER_CREDENTIAL_TABLE, TableSet11),
    validate_restored_tables(RestoredTabs, TableSet12).

validate_restored_tables([], ExpectedTableSet) ->
    case sets:size(ExpectedTableSet) of
        0 ->
            ok;
        _ ->
            {error, {missing_tables, ExpectedTableSet}}
    end;
validate_restored_tables([T|Rest], ExpectedTableSet) ->
    validate_restored_tables(Rest, sets:del_element(T, ExpectedTableSet)).


%% @doc Update available commands
%%
-spec(update_available_commands(atom | list()) ->
             ok).
update_available_commands(AvailableCommands) ->
    {atomic,ok} = mnesia:clear_table(?TBL_AVAILABLE_CMDS),
    case AvailableCommands of
        all ->
            lists:foreach(
              fun({C, H}) ->
                      leo_manager_mnesia:insert_available_command(C,H)
              end, ?COMMANDS);
        CmdL ->
            lists:foreach(
              fun({C1, H}) ->
                      case lists:foldl(
                             fun(C2, false) when C1 == C2 -> true;
                                (_,  Ret) -> Ret
                             end, false, CmdL) of
                          true ->
                              leo_manager_mnesia:insert_available_command(C1,H);
                          false ->
                              void
                      end
              end, ?COMMANDS)
    end,
    ok.
