function bits = qpsk_demodulate(X_est)
%QPSK_DEMODULATE Giải ánh xạ QPSK Gray bằng quyết định theo dấu I và Q.
%   Mỗi hàng của X_est là một symbol dữ liệu; mỗi cột là một symbol OFDM.
%   Mỗi cột của bits gồm các bit theo thứ tự từng cặp QPSK.

numberOfDataSymbols = size(X_est, 1);
numberOfOFDMSymbols = size(X_est, 2);

bits = zeros(2 * numberOfDataSymbols, numberOfOFDMSymbols);

% Quy ước Gray: bit thứ nhất theo dấu trục Q, bit thứ hai theo dấu trục I.
bits(1:2:end, :) = imag(X_est) < 0;
bits(2:2:end, :) = real(X_est) < 0;
end
