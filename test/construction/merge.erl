-module(merge).

-include_lib("eunit/include/eunit.hrl").

-define(FILENAME, "test/construction/" ?MODULE_STRING ".yaml").

setup() ->
    application:start(yamerl).

merge_proplist_simple_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
          [
            [
              [
                {"x", 1},
                {"y", 2}
              ],
              [
                {"x", 4},
                {"y", 2},
                {"r", 10}
              ]
            ]
          ],
          yamerl_constr:file(?FILENAME, [
              {detailed_constr, false},
              {node_mods, [yamerl_node_merge]}
            ])
        )
      ]
    }.

merge_proplist_detailed_test_() ->
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
           [
             {yamerl_doc,
                      {yamerl_seq,yamerl_node_seq,"tag:yaml.org,2002:seq",
                          [{line,1},{column,1}],
                          [{yamerl_map,yamerl_node_map,
                               "tag:yaml.org,2002:map",
                               [{line,2},{column,3}],
                               [{{yamerl_str,yamerl_node_str,
                                     "tag:yaml.org,2002:str",
                                     [{line,2},{column,3}],
                                     "x"},
                                 {yamerl_int,yamerl_node_int,
                                     "tag:yaml.org,2002:int",
                                     [{line,2},{column,6}],
                                     1}},
                                {{yamerl_str,yamerl_node_str,
                                     "tag:yaml.org,2002:str",
                                     [{line,3},{column,3}],
                                     "y"},
                                 {yamerl_int,yamerl_node_int,
                                     "tag:yaml.org,2002:int",
                                     [{line,3},{column,6}],
                                     2}}]},
                           {yamerl_map,yamerl_node_map,
                               "tag:yaml.org,2002:map",
                               [{line,4},{column,3}],
                               [{{yamerl_str,yamerl_node_str,
                                     "tag:yaml.org,2002:str",
                                     [{line,6},{column,3}],
                                     "x"},
                                 {yamerl_int,yamerl_node_int,
                                     "tag:yaml.org,2002:int",
                                     [{line,6},{column,6}],
                                     4}},
                                {{yamerl_str,yamerl_node_str,
                                     "tag:yaml.org,2002:str",
                                     [{line,3},{column,3}],
                                     "y"},
                                 {yamerl_int,yamerl_node_int,
                                     "tag:yaml.org,2002:int",
                                     [{line,3},{column,6}],
                                     2}},
                                {{yamerl_str,yamerl_node_str,
                                     "tag:yaml.org,2002:str",
                                     [{line,5},{column,3}],
                                     "r"},
                                 {yamerl_int,yamerl_node_int,
                                     "tag:yaml.org,2002:int",
                                     [{line,5},{column,6}],
                                     10}}]}],
                          2}}
           ],
           yamerl_constr:file(?FILENAME, [
               {detailed_constr, true},
               {node_mods, [yamerl_node_merge]}
            ])
        )
      ]
    }.

merge_map_simple_test_() ->
    case erlang:function_exported(maps, from_list, 1) of
        true  -> merge_map_simple();
        false -> []
    end.

merge_map_simple() ->
    SubMap1 = maps:from_list([{"x", 1}, {"y", 2}]),
    SubMap2 = maps:from_list([{"r", 10}, {"x", 4}, {"y", 2}]),
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
          [
            [
              SubMap1,
              SubMap2
            ]
          ],
          yamerl_constr:file(?FILENAME, [
              {detailed_constr, false},
              {node_mods, [yamerl_node_merge]},
              {map_node_format, map}
            ])
        )
      ]
    }.

merge_map_detailed_test_() ->
    case erlang:function_exported(maps, from_list, 1) of
        true  -> merge_map_detailed();
        false -> []
    end.

merge_map_detailed() ->
    SubMap1 = maps:from_list(
                [{{yamerl_str,yamerl_node_str,"tag:yaml.org,2002:str",
                   [{line,2},{column,3}],
                   "x"},
                  {yamerl_int,yamerl_node_int,"tag:yaml.org,2002:int",
                   [{line,2},{column,6}],
                   1}},
                 {{yamerl_str,yamerl_node_str,"tag:yaml.org,2002:str",
                   [{line,3},{column,3}],
                   "y"},
                  {yamerl_int,yamerl_node_int,"tag:yaml.org,2002:int",
                   [{line,3},{column,6}],
                   2}}
                ]),
    SubMap2 = maps:from_list(
                [{{yamerl_str,yamerl_node_str,"tag:yaml.org,2002:str",
                   [{line,3},{column,3}],
                   "y"},
                  {yamerl_int,yamerl_node_int,"tag:yaml.org,2002:int",
                   [{line,3},{column,6}],
                   2}},
                {{yamerl_str,yamerl_node_str,"tag:yaml.org,2002:str",
                   [{line,5},{column,3}],
                   "r"},
                  {yamerl_int,yamerl_node_int,"tag:yaml.org,2002:int",
                   [{line,5},{column,6}],
                   10}},
                {{yamerl_str,yamerl_node_str,"tag:yaml.org,2002:str",
                   [{line,6},{column,3}],
                   "x"},
                  {yamerl_int,yamerl_node_int,"tag:yaml.org,2002:int",
                   [{line,6},{column,6}],
                   4}}
                ]),
    {setup,
      fun setup/0,
      [
        ?_assertMatch(
          [
            {yamerl_doc,
              {yamerl_seq,yamerl_node_seq,"tag:yaml.org,2002:seq",
                [{line,1},{column,1}],
                [{yamerl_map,yamerl_node_map,"tag:yaml.org,2002:map",
                  [{line,2},{column,3}],
                  SubMap1},
                 {yamerl_map,yamerl_node_map,"tag:yaml.org,2002:map",
                  [{line,4},{column,3}],
                  SubMap2}],
              2}
            }
          ],
          yamerl_constr:file(?FILENAME, [
              {detailed_constr, true},
              {node_mods, [yamerl_node_merge]},
              {map_node_format, map}
            ])
        )
      ]
    }.

