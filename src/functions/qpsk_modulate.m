function dataSymbols = qpsk_modulate(bitsTx, Ndata)
%QPSK_MODULATE Ánh xạ từng cặp bit thành symbol QPSK Gray.
%   Bit thứ nhất điều khiển dấu trục Q, bit thứ hai điều khiển dấu trục I.
%   Mỗi hàng của dataSymbols là một subcarrier dữ liệu, mỗi cột là một
%   symbol OFDM. Công suất trung bình của mỗi symbol QPSK bằng 1.

bitsPerQpskSymbol = 2;
numBitsPerOfdmSymbol = Ndata * bitsPerQpskSymbol;

assert(mod(length(bitsTx), numBitsPerOfdmSymbol) == 0, ...
    'Số bit phải là bội của số bit trong một symbol OFDM.');

numOfdmSymbols = length(bitsTx) / numBitsPerOfdmSymbol;
bitPairs = reshape(bitsTx, bitsPerQpskSymbol, []);

quadrature = 1 - 2 * bitPairs(1, :);
inPhase = 1 - 2 * bitPairs(2, :);

qpskVector = (inPhase + 1i * quadrature) / sqrt(2);
dataSymbols = reshape(qpskVector, Ndata, numOfdmSymbols);
end

