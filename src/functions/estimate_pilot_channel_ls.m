function H_pilot = estimate_pilot_channel_ls(Y, pilot_symbols, pilot_indices)
%ESTIMATE_PILOT_CHANNEL_LS Tính ước lượng LS tại các vị trí pilot.
%   Mỗi hàng của H_pilot ứng với một pilot, mỗi cột ứng với một symbol.

% Chia tín hiệu thu tại pilot cho giá trị pilot đã biết ở phía phát.
H_pilot = Y(pilot_indices, :) ./ pilot_symbols(:);
end
