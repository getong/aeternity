%%%-------------------------------------------------------------------
%%% @copyright (C) 2017, Aeternity Anstalt
%%% @doc
%%%    A library providing Cuckoo Cycle PoW generation and verification.
%%%    A NIF interface to the C/C++ Cuckoo Cycle implementation of
%%%    John Tromp:  https://github.com/tromp/cuckoo
%%%    White paper: https://github.com/tromp/cuckoo/blob/master/doc/cuckoo.pdf?raw=true
%%% @end
%%%-------------------------------------------------------------------
-module(aec_pow_cuckoo).

-export([generate/6,
         verify/4,
         recalculate_difficulty/3]).

-ifdef(TEST).
-compile(export_all).
-endif.

-on_load(init/0).

-type pow_cuckoo_solution() :: [integer()].
-type pow_cuckoo_result() :: {'ok', Key1 :: integer(), Key2 :: integer(),
                              Soln :: pow_cuckoo_solution()} | {'error', atom()}.

-export_type([pow_cuckoo_result/0,
              pow_cuckoo_solution/0]).

%%%=============================================================================
%%% NIF initialization
%%%=============================================================================

init() ->
    ok = erlang:load_nif(filename:join([code:priv_dir(aecore),
                                        "aec_pow_cuckoo_nif"]), 0).

%%%=============================================================================
%%% API
%%%=============================================================================

%%------------------------------------------------------------------------------
%% Proof of Work generation, multiple attempts
%%------------------------------------------------------------------------------
-spec generate(Data :: binary(), Nonce :: integer(), Difficulty :: aec_sha256:sci_int(),
               Trims :: integer(), Threads :: integer(), Retries :: integer()) -> 
                      pow_cuckoo_result().
generate(_Data, _Nonce, _Difficulty, _Trims, _Threads, 0) ->
    {error, generation_count_exhausted};
generate(Data, Nonce, Difficulty, Trims, Threads, Retries) when Retries > 0 ->
    Header = case size(Data) of
                 L when L =< 80 ->
                     Data;
                 _ ->
                     <<H:80/binary, _>> = Data,
                     H
             end,
    case generate(binary_to_list(Header), Nonce, Trims, Threads) of
        {error, no_solutions} ->
            generate(Header, Nonce + 1, Difficulty, Trims, Threads, Retries - 1);
        {ok, _Key1, _Key2, Soln} = Result ->
            case test_difficulty(Soln, Difficulty) of
                true ->
                    Result;
                false ->
                    generate(Header, Nonce + 1, Difficulty, Trims, Threads, Retries - 1)
            end
    end.

%%------------------------------------------------------------------------------
%% Proof of Work verification (with difficulty check)
%%------------------------------------------------------------------------------
-spec verify(Key1 :: integer(), Key2 :: integer(),
             Soln :: pow_cuckoo_solution(), Difficulty :: aec_sha256:sci_int()) ->
                    boolean().
verify(Key1, Key2, Soln, Difficulty) ->
    case test_difficulty(Soln, Difficulty) of
        true ->
            verify(Key1, Key2, Soln);
        false ->
            false
    end.

%%------------------------------------------------------------------------------
%% Adjust difficulty so that generation of new blocks proceeds at the expected pace
%%------------------------------------------------------------------------------
-spec recalculate_difficulty(aec_sha256:sci_int(), integer(), integer()) -> 
                                    aec_sha256:sci_int().
recalculate_difficulty(Difficulty, Expected, Actual) ->
    DiffInt = aec_sha256:scientific_to_integer(Difficulty),
    aec_sha256:integer_to_scientific(max(1, DiffInt * Expected div Actual)).


%%%=============================================================================
%%% Internal functions
%%%=============================================================================

%%------------------------------------------------------------------------------
%% Proof of Work generation, a single attempt
%%------------------------------------------------------------------------------
-spec generate(Header :: string(), Nonce :: integer(), Trims :: integer(),
               Threads :: integer()) -> pow_cuckoo_result().
generate(_Header, _Nonce, _Trims, _Threads) ->
    exit(nif_library_not_loaded).

%%------------------------------------------------------------------------------
%% Proof of Work verification (without difficulty check)
%%------------------------------------------------------------------------------
-spec verify(Key1 :: integer(), Key2 :: integer(),
             Soln :: pow_cuckoo_solution()) -> boolean().
verify(_Key1, _Key2, _Soln) ->
    exit(nif_library_not_loaded).

%%------------------------------------------------------------------------------
%% White paper, section 9: rather than adjusting the nodes/edges ratio, a
%% hash-based difficulty is suggested: the sha256 hash of the cycle nonces
%% is restricted to be under the difficulty value (0 < difficulty < 2^256).
%%------------------------------------------------------------------------------
-spec test_difficulty(Soln :: pow_cuckoo_solution(), Difficulty :: aec_sha256:sci_int()) ->
                             boolean().
test_difficulty(Soln, Difficulty) ->
    Hash = aec_sha256:hash(lists:sort(Soln)),
    aec_sha256:binary_to_scientific(Hash) < Difficulty.
