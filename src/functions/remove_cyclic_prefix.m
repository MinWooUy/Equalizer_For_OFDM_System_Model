function rx_no_cp = remove_cyclic_prefix(rx, CP)
%REMOVE_CYCLIC_PREFIX Remove the CP from the start of each OFDM symbol.
%   Each column of rx contains one OFDM symbol, including its CP.

rx_no_cp = rx(CP + 1:end, :);
end
