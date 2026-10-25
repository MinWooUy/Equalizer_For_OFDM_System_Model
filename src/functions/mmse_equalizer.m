function X_est = mmse_equalizer(Y, H_est, noise_variance, symbol_variance)
%MMSE_EQUALIZER Cân bằng MMSE trên từng sóng mang con OFDM.
%   noise_variance là phương sai nhiễu AWGN phức.
%   symbol_variance là công suất trung bình của symbol phát.

% Tính trọng số MMSE và áp dụng lên tín hiệu thu tại từng subcarrier.
X_est = Y .* conj(H_est) ./ ...
    (abs(H_est).^2 + noise_variance ./ symbol_variance);
end
