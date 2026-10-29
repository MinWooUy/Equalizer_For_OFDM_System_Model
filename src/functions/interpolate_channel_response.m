function H_centered = interpolate_channel_response(centered_indices, H_pilot, NFFT)
%INTERPOLATE_CHANNEL_RESPONSE Nội suy kênh trên toàn bộ subcarrier.

% Lặp vị trí pilot sang hai chu kỳ phổ kề để nội suy tuần hoàn qua biên.
% đáp ứng kênh $H(k)$ tuần hoàn theo $k$ với chu kỳ $N$.
extended_indices = [centered_indices - NFFT; centered_indices; ...
    centered_indices + NFFT];

% Lặp các giá trị kênh pilot tương ứng với những vị trí đã mở rộng.
extended_H = [H_pilot; H_pilot; H_pilot];

% Nội suy spline tại tất cả NFFT vị trí trong phổ đã fftshift.
centered_subcarriers = (1:NFFT).';
H_centered = interp1(extended_indices, extended_H, ...
    centered_subcarriers, 'spline');
end
