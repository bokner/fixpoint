-module(bit_vector).

-export([new/1, get/2, set/2, clear/2, flip/2, print/1]).


% Allocate atomics to contain the data + 2 bytes for min and max
new(Size) ->
    Words = (Size + 63) div 64,
    Atomics = atomics:new(Words + 2, [{signed, false}]),
    atomics:put(Atomics, Words + 1, 0), %% Set 'min' to lowest possible
    atomics:put(Atomics, Words + 2, (1 bsl 64)-1), %% Set 'max' to highest possible

    {?MODULE, Size, Atomics}.

    

get({?MODULE, _Size, Aref}, Bix) ->
    Wix = (Bix div 64) + 1,
    Mask = (1 bsl (Bix rem 64)),    
    case atomics:get(Aref, Wix) band Mask of
        0 -> 0;
        Mask -> 1
    end.

set({?MODULE, _Size, Aref}, Bix) ->
    Mask = (1 bsl (Bix rem 64)),    
    update(Aref, Bix, fun(Word) -> Word bor Mask end).

clear({?MODULE, _Size, Aref}, Bix) ->
    Mask = bnot (1 bsl (Bix rem 64)),
    update(Aref, Bix, fun(Word) -> Word band Mask end).

flip({?MODULE, _Size, Aref}, Bix) ->
    Mask = (1 bsl (Bix rem 64)),
    update(Aref, Bix, fun(Word) -> Word bxor Mask end).

print({?MODULE, Size, _Aref} = BV) ->
    print(BV, Size-1).
print(BV, 0) ->
    io:format("~B~n",[get(BV, 0)]);
print(BV, Slot) ->
    io:format("~B",[get(BV, Slot)]),
    print(BV, Slot-1).

update(Aref, Bix, Fun) ->
    Wix = (Bix div 64) + 1,
    update_loop(Aref, Wix, Fun, atomics:get(Aref, Wix)).

update_loop(Aref, Wix, Fun, Current) ->
    atomics:put(Aref, Wix, Fun(Current)).
    %case atomics:compare_exchange(Aref, Wix, Expected, Fun(Expected)) of
    %    ok ->
    %        ok;
    %    Was ->
    %        update_loop(Aref, Wix, Fun, Was)
    %end.