function xCP = add_cyclic_prefix(x, NCP)
%ADD_CYCLIC_PREFIX Chèn NCP mẫu cuối lên đầu mỗi symbol OFDM.
%   Mỗi cột của x chứa một symbol OFDM chưa có CP.

assert(NCP >= 0 && NCP <= size(x, 1), ...
    'NCP phải nằm trong khoảng từ 0 đến độ dài symbol OFDM.');

if NCP == 0
    xCP = x;
    return;
end

cp = x(end-NCP+1:end, :);
xCP = [cp; x];
end

