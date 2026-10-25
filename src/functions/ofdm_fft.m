function Y = ofdm_fft(rx_no_cp, NFFT)
%OFDM_FFT Convert CP-removed OFDM symbols to the frequency domain.
%   Each column of rx_no_cp contains one OFDM symbol without its CP.

Y = fft(rx_no_cp, NFFT, 1);
end
