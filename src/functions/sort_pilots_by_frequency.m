function [centered_indices, H_pilot] = sort_pilots_by_frequency( ...
    pilot_indices, H_pilot, NFFT)
%SORT_PILOTS_BY_FREQUENCY Sắp xếp pilot theo thứ tự tần số sau fftshift.

% Đổi chỉ số FFT ban đầu sang vị trí tương ứng trong phổ đã fftshift.
centered_indices = mod(pilot_indices(:) - 1 + floor(NFFT / 2), NFFT) + 1;

% Sắp xếp vị trí pilot tăng dần và lấy thứ tự sắp xếp.
[centered_indices, order] = sort(centered_indices);

% Sắp xếp các ước lượng kênh pilot theo đúng thứ tự vị trí mới.
H_pilot = H_pilot(order, :);
end
