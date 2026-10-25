function [H_est, h_est] = estimate_channel_ls_delay( ...
    Y, pilot_symbols, pilot_indices, NFFT, Lh)
%ESTIMATE_CHANNEL_LS_DELAY Ước lượng kênh LS trong miền trễ từ pilot.
%   Mỗi cột của Y là một symbol OFDM. Hàm trả về đáp ứng xung h_est
%   và đáp ứng tần số H_est trên NFFT subcarrier.

% Lấy tín hiệu thu tại pilot và chia cho giá trị pilot đã biết.
Y_pilot = Y(pilot_indices, :) ./ pilot_symbols(:);

% Tạo ma trận Fourier mô tả ảnh hưởng của Lh tap lên các pilot.
subcarrierNumbers = pilot_indices(:) - 1;
tapNumbers = 0:Lh-1;
pilotMatrix = exp(-1i * 2 * pi / NFFT * ...
    (subcarrierNumbers * tapNumbers));

% Tìm các tap kênh sao cho sai số bình phương tại pilot nhỏ nhất.
h_est = pilotMatrix \ Y_pilot;

% Chuyển đáp ứng xung ước lượng sang miền tần số cho bộ cân bằng.
H_est = fft(h_est, NFFT, 1);
end
