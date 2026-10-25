function [txSignal, dataSymbols, X, x, xCP] = ofdm_transmitter( ...
    bitsTx, NFFT, NCP, dataIndices, pilotIndices, pilotPattern)
%OFDM_TRANSMITTER Thực hiện toàn bộ chuỗi xử lý của bộ phát OFDM.
%   Các chỉ số subcarrier phải theo thứ tự FFT gốc của MATLAB.

Ndata = length(dataIndices);

% Điều chế QPSK.
dataSymbols = qpsk_modulate(bitsTx, Ndata);

% Ánh xạ data và pilot lên lưới subcarrier.
X = map_ofdm_subcarriers( ...
    dataSymbols, pilotPattern, dataIndices, pilotIndices, NFFT);

% Chuyển sang miền thời gian và chèn Cyclic Prefix.
x = ofdm_ifft(X, NFFT);
xCP = add_cyclic_prefix(x, NCP);

% Ghép các symbol thành chuỗi phát nối tiếp.
txSignal = serialize_ofdm_symbols(xCP);
end

