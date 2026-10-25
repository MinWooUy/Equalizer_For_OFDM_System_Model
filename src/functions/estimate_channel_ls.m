function H_est = estimate_channel_ls(Y, pilot_symbols, pilot_indices, NFFT)
%ESTIMATE_CHANNEL_LS Ước lượng đáp ứng kênh từ các pilot đã biết.
%   Mỗi cột của Y là một symbol OFDM theo thứ tự FFT chưa dịch.

% Tính ước lượng LS tại các vị trí pilot.
H_pilot = estimate_pilot_channel_ls(Y, pilot_symbols, pilot_indices);

% Sắp xếp vị trí và giá trị pilot theo thứ tự tần số đã fftshift.
[centered_indices, H_pilot] = sort_pilots_by_frequency( ...
    pilot_indices, H_pilot, NFFT);

% Nội suy các giá trị pilot để ước lượng kênh trên toàn bộ subcarrier.
H_centered = interpolate_channel_response(centered_indices, H_pilot, NFFT);

% Đưa đáp ứng kênh về cùng thứ tự FFT với tín hiệu Y.
H_est = restore_fft_order(H_centered);
end
