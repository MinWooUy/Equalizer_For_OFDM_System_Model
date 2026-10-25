function H = channel_frequency_response(h, NFFT)
% Return the channel frequency response on NFFT subcarriers.
H = fft(h(:), NFFT);
end
