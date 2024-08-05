-module(bit_vector).

-export([new/1, get/2, set/2, clear/2, flip/2, print/1]).


% Allocate atomics to contain the data + 2 bytes for min and max
new(Size) ->
    Words = (Size + 63) div 64,
    Atomics = atomics:new(Words + 1, [{signed, false}]),
    atomics:put(Atomics, Words + 1, 0), %% Set 'min_max' to lowest possible


    {?MODULE, Atomics}.

    

get({?MODULE, Aref}, Bix) ->
    Wix = (Bix div 64) + 1,
    Mask = (1 bsl (Bix rem 64)),    
    case atomics:get(Aref, Wix) band Mask of
        0 -> 0;
        Mask -> 1
    end.

set({?MODULE, Aref}, Bix) ->
    Mask = (1 bsl (Bix rem 64)),    
    update(Aref, Bix, fun(Word) -> Word bor Mask end).

clear({?MODULE, Aref}, Bix) ->
    Mask = bnot (1 bsl (Bix rem 64)),
    update(Aref, Bix, fun(Word) -> Word band Mask end).

flip({?MODULE, Aref}, Bix) ->
    Mask = (1 bsl (Bix rem 64)),
    update(Aref, Bix, fun(Word) -> Word bxor Mask end).

print({?MODULE, Aref} = BV) ->
    #{size := Size} = atomics:info(Aref),
    print(BV, Size).
print(BV, 0) ->
    io:format("~B~n",[get(BV, 0)]);
print(BV, Slot) ->
    io:format("~B",[get(BV, Slot)]),
    print(BV, Slot-1).

update(Aref, Bix, Fun) ->
    Wix = (Bix div 64) + 1,
    update_loop(Aref, Wix, Fun, atomics:get(Aref, Wix)).

update_loop(Aref, Wix, Fun, Current) ->
    case atomics:compare_exchange(Aref, Wix, Current, Fun(Current)) of
       ok ->
           ok;
       Was ->
           update_loop(Aref, Wix, Fun, Was)
    end.