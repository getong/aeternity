%%%=============================================================================
%%% @copyright (C) 2017, Aeternity Anstalt
%%% @doc
%%%   Unit tests for the aec_pow_cuckoo module
%%% @end
%%%=============================================================================
-module(aec_pow_cuckoo_tests).

-ifdef(TEST).

-include_lib("eunit/include/eunit.hrl").

-define(TEST_MODULE, aec_pow_cuckoo).

pow_test_() ->
    {setup,
     fun() -> ok end ,
     fun(_) -> ok end,
     [{"Fail if retry count is zero",
       fun() ->
               ?assertEqual({error, generation_count_exhausted},
                            ?TEST_MODULE:generate(<<"hello there">>, 5555, 0, 7, 7, 0))
       end},
      {"Generate with a winning nonce and big difficulty, verify it",
       {timeout, 10000,
        fun() ->
                %% succeeds in a single step
                BigDiff = 256*256 + 255 + 1,
                Res = ?TEST_MODULE:generate(<<"wsffgujnjkqhduihsahswgdf">>, 46,
                                            BigDiff, 7, 20, 3),
                ?debugFmt("Received result ~p~n", [Res]),
                ?assertEqual(ok, element(1, Res)),

                %% verify the beast
                {ok, Key1, Key2, Soln} = Res,
                ?assertEqual(true, ?TEST_MODULE:verify(Key1, Key2, Soln, BigDiff))
        end}
      },
      {"Generate with a winning nonce but difficulty, shall fail",
       {timeout, 10000,
        fun() ->
                %% succeeds in a single step
                SmallDiff = 256*2 + 1,
                Res = ?TEST_MODULE:generate(<<"wsffgujnjkqhduihsahswgdf">>, 46,
                                            SmallDiff, 7, 20, 2),
                ?debugFmt("Received result ~p~n", [Res]),
                ?assertEqual({error, generation_count_exhausted}, Res)
        end}
      }
     ]
    }.

-endif.
