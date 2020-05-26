-module(yamerl_node_merge).

-include("yamerl_errors.hrl").
-include("yamerl_tokens.hrl").
-include("yamerl_nodes.hrl").
-include("internal/yamerl_constr.hrl").

%% Public API.
-export([
    tags/0,
    try_construct_token/3,
    construct_token/3,
    construct_node/3,
    node_pres/1
  ]).

-define(TAG, "tag:yaml.org,2002:merge").
-define(IS_MERGE(S), S == "<<").

-record(map_builder,
    {format,
     state,
     keys :: proplist:proplist(),
     data :: proplist:proplist() | maps:maps()}).

%% -------------------------------------------------------------------
%% Public API.
%% -------------------------------------------------------------------
tags() -> [?TAG].

try_construct_token(Constr, Node,
  #yamerl_collection_start{kind = mapping} = Token) ->
    construct_token(Constr, Node, Token);
try_construct_token(_, _, _) ->
    unrecognized.

construct_token(Constr, Node, Token) ->
    case yamerl_node_map:construct_token(Constr, Node, Token) of
        {unfinished, N, IsLeaf} ->
            {unfinished, N#unfinished_node{module = ?MODULE}, IsLeaf};
        Else ->
            Else
    end.

construct_node(Constr,
  #unfinished_node{path = {map, _},
    priv = #map_builder{state= {'$expecting_value', Key}} = Builder} = Node,
  Value) ->
    case is_merge(Constr, Key, Value) of
        {true, Values} ->
            Fun = fun({K, V}, B) ->
                yamerl_node_map:set_kv(Constr, K, V, B)
            end,
            Node1 = Node#unfinished_node{
                path = {map, undefined},
                priv = lists:foldl(Fun, Builder, Values)
            },
            {unfinished, Node1, false};
        false ->
            case yamerl_node_map:construct_node(Constr, Node, Value) of
                {unfinished, N, IsLeaf} ->
                    {unfinished, N#unfinished_node{module = ?MODULE}, IsLeaf}
            end
        end;
construct_node(Constr, Node, Child) ->
    case yamerl_node_map:construct_node(Constr, Node, Child) of
        {unfinished, N, IsLeaf} ->
            {unfinished, N#unfinished_node{module = ?MODULE}, IsLeaf}
    end.

is_merge(#yamerl_constr{detailed_constr = false}, Key, Value) when Key == "<<" ->
    case is_list(Value) of
        true ->
            {true, Value};
        false ->
            {true, maps:to_list(Value)}
    end;
is_merge(#yamerl_constr{detailed_constr = true},
    #yamerl_str{text = Key}, Value) when Key == "<<" ->
    case is_list(Value#yamerl_map.pairs) of
        true ->
            {true, Value#yamerl_map.pairs};
        false ->
            {true, maps:to_list(Value#yamerl_map.pairs)}
    end;
is_merge(_Constr, _Key, _Value) ->
    false.

node_pres(Node) ->
    ?NODE_PRES(Node).

