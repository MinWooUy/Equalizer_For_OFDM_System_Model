function H = restore_fft_order(H_centered)
%RESTORE_FFT_ORDER Đưa phổ từ thứ tự fftshift về thứ tự FFT ban đầu.

H = ifftshift(H_centered, 1);
end
