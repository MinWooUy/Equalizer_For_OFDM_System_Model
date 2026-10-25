function X_est = zf_equalizer(Y, H_est)
%ZF_EQUALIZER Cân bằng Zero-Forcing trên từng subcarrier OFDM.
%   Y và H_est có số hàng ứng với subcarrier, mỗi cột là một symbol OFDM.

% Nhân với liên hợp của H rồi chia cho bình phương độ lớn kênh.
% eps giúp tránh phép chia cho 0 ở subcarrier bị suy hao rất mạnh.
X_est = Y .* conj(H_est) ./ (abs(H_est).^2 + eps);
end
