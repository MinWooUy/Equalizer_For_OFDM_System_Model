function x = ofdm_ifft(X, NFFT)
%OFDM_IFFT Chuyển các symbol OFDM từ miền tần số sang miền thời gian.
%   Mỗi cột của X sử dụng thứ tự FFT gốc và tạo ra một symbol OFDM.

x = ifft(X, NFFT, 1);
end

