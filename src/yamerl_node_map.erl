%-
% Copyright (c) 2012-2014 Yakaz
% Copyright (c) 2016-2018 Jean-Sébastien Pédron <jean-sebastien.pedron@dumbbell.fr>
% All rights reserved.
%
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions
% are met:
% 1. Redistributions of source code must retain the above copyright
%    notice, this list of conditions and the following disclaimer.
% 2. Redistributions in binary form must reproduce the above copyright
%    notice, this list of conditions and the following disclaimer in the
%    documentation and/or other materials provided with the distribution.
%
% THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
% ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
% ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
% FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
% DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
% OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
% HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
% LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
% OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
% SUCH DAMAGE.

%% @private

-module(yamerl_node_map).

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
    node_pres/1,
    set_kv/4
  ]).

-define(TAG, "tag:yaml.org,2002:map").

-record(map_builder,
    {format,
     state,
     keys,
     data}).
%% -------------------------------------------------------------------
%% Public API.
%% -------------------------------------------------------------------

tags() -> [?TAG].

try_construct_token(Constr, Node,
  #yamerl_collection_start{kind = mapping} = Token) ->
    construct_token(Constr, Node, Token);
try_construct_token(_, _, _) ->
    unrecognized.

construct_token(Constr, undefined, #yamerl_collection_start{} = Token) ->
    Map = new_builder(Constr),
    Pres = yamerl_constr:get_pres_details(Token),
    Node = #unfinished_node{
      path = {map, undefined},
      pres = Pres,
      priv = Map
    },
    {unfinished, Node, false};
construct_token(_, #unfinished_node{priv = Map} = Node,
  #yamerl_mapping_key{}) ->
    Node1 = Node#unfinished_node{
      priv = Map#map_builder{state = '$expecting_key'}
    },
    {unfinished, Node1, false};
construct_token(_, #unfinished_node{priv = #map_builder{state = State} = Map} = Node,
  #yamerl_mapping_value{}) when State =/= '$expecting_key' ->
    Node1 = Node#unfinished_node{
      priv = Map#map_builder{state = {'$expecting_value', Map#map_builder.state}}
    },
    {unfinished, Node1, false};

construct_token(#yamerl_constr{detailed_constr = false},
  #unfinished_node{priv = #map_builder{state = none} = Builder}, #yamerl_collection_end{}) ->
    Node = finalize_builder(Builder),
    {finished, Node};
construct_token(#yamerl_constr{detailed_constr = true},
  #unfinished_node{pres = Pres, priv = #map_builder{state = none} = Builder}, #yamerl_collection_end{}) ->
    Map1 = finalize_builder(Builder),
    Node = #yamerl_map{
      module = ?MODULE,
      tag    = ?TAG,
      pres   = Pres,
      pairs  = Map1
    },
    {finished, Node};

construct_token(_, _, Token) ->
    Error = #yamerl_parsing_error{
      name   = not_a_mapping,
      token  = Token,
      text   = "Invalid mapping",
      line   = ?TOKEN_LINE(Token),
      column = ?TOKEN_COLUMN(Token)
    },
    throw(Error).

construct_node(_,
  #unfinished_node{path = {map, undefined},
    priv = #map_builder{state = '$expecting_key'} = Builder} = Node,
  Key) ->
    Node1 = Node#unfinished_node{
      path = {map, Key},
      priv = Builder#map_builder{state = Key}
    },
    {unfinished, Node1, false};
construct_node(Constr,
  #unfinished_node{path = {map, _},
    priv = #map_builder{state= {'$expecting_value', Key}} = Builder} = Node,
  Value) ->
    Map1 = set_kv(Constr, Key, Value, Builder),
    Node1 = Node#unfinished_node{
      path = {map, undefined},
      priv = Map1
    },
    {unfinished, Node1, false}.

node_pres(Node) ->
    ?NODE_PRES(Node).

node_as_proplist_or_map(#yamerl_constr{ext_options = Options}) ->
    proplists:get_value(map_node_format, Options, proplist).

new_builder(Constr) ->
    Format = node_as_proplist_or_map(Constr),
    Map = #map_builder{
        format = Format,
        state = none,
        keys = []},
    case Format of
        proplist ->
            Map#map_builder{data = []};
        map ->
            Map#map_builder{data = maps:new()}
    end.

finalize_builder(#map_builder{data = Map, format = proplist}) ->
    lists:reverse(Map);
finalize_builder(#map_builder{data = Map, format = map}) ->
    Map.

set_kv(#yamerl_constr{detailed_constr = false},
       Key,
       Value,
       #map_builder{format = proplist, data = Map} = Builder) ->
    case lists:keymember(Key, 1, Map) of
        true ->
            Builder#map_builder{state = none, data = lists:keyreplace(Key, 1, Map, {Key, Value})};
        false ->
            Builder#map_builder{state = none, data = [{Key, Value} | Map]}
    end;
set_kv(#yamerl_constr{detailed_constr = false},
       Key,
       Value,
       #map_builder{format = map, data = Map} = Builder) ->
    Builder#map_builder{state = none, data = maps:put(Key, Value, Map)};

set_kv(#yamerl_constr{detailed_constr = true},
       Key,
       Value,
       #map_builder{format = proplist, keys = Keys, data = Map} = Builder) ->
    case find(Key, Keys) of
        none ->
            RawKey = erlang:delete_element(#yamerl_str.pres, Key),
            Builder#map_builder{state = none, keys = [{RawKey, Key} | Keys], data = [{Key, Value} | Map]};
        {RawKey, MapKey} ->
            Fun = fun({K, _V}) when K == MapKey ->
                    {Key, Value};
                (Else) ->
                    Else
                end,
            Keys1 = [{RawKey, Key} | lists:delete({RawKey, MapKey}, Keys)],
            Builder#map_builder{state = none, keys = Keys1, data = lists:map(Fun, Map)}
    end;
set_kv(#yamerl_constr{detailed_constr = true},
       Key,
       Value,
       #map_builder{format = map, keys = Keys, data = Map} = Builder) ->
    case find(Key, Keys) of
        none ->
            RawKey = erlang:delete_element(#yamerl_str.pres, Key),
            Builder#map_builder{state = none, keys = [{RawKey, Key} | Keys], data = maps:put(Key, Value, Map)};
        {RawKey, MapKey} ->
            Keys1 = [{RawKey, Key} | lists:delete({RawKey, MapKey}, Keys)],
            Maps1 = maps:put(Key, Value, maps:remove(MapKey, Map)),
            Builder#map_builder{state = none, keys = Keys1, data = Maps1}
    end.

find(Key0, Keys) ->
    Key = erlang:delete_element(#yamerl_str.pres, Key0),
    proplists:lookup(Key, Keys).
