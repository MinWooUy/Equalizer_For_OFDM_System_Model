function X_est = zf_equalizer(Y, H_est)
X_est = Y .* conj(H_est) ./ (abs(H_est).^2 + eps);
end