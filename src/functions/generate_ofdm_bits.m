function bitsTx = generate_ofdm_bits(Ndata, numOfdmSymbols, M)
%GENERATE_OFDM_BITS Sinh chuỗi bit cho các symbol OFDM.
%   Mỗi symbol OFDM chứa Ndata symbol điều chế QPSK.

assert(M == 4, 'Bộ phát hiện tại chỉ hỗ trợ điều chế QPSK với M = 4.');

bitsPerQpskSymbol = log2(M);
numBitsPerOfdmSymbol = Ndata * bitsPerQpskSymbol;

bitsTx = randi( ...
    [0 1], ...
    numBitsPerOfdmSymbol * numOfdmSymbols, ...
    1);
end

