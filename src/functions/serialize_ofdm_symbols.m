function txSignal = serialize_ofdm_symbols(xCP)
%SERIALIZE_OFDM_SYMBOLS Ghép các symbol OFDM thành chuỗi phát nối tiếp.
%   Mỗi cột của xCP được ghép hoàn chỉnh trước khi chuyển sang cột kế tiếp.

txSignal = xCP(:);
end

