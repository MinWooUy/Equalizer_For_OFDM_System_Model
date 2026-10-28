%% pilot_sweep.m - Khảo sát ảnh hưởng của số pilot lên BER (nhánh cân bằng ZF)
% Dùng lại các hàm trong thư mục functions của chương trình chính.
clear; close all; clc;

srcPath = fileparts(mfilename('fullpath'));
addpath(fullfile(srcPath, 'functions'));

%% Tham số
NFFT = 64;
NCP = 16;
M = 4;
numOfdmSymbols = 2000;
Lh = 10;                            % Số tap kênh đa đường
EbN0dB = 0:2:20;
activeIndices = [2:27 39:64];       % 52 sóng mang active, giống chương trình chính
NpList = [10 12 16 20 26];          % Các số pilot cần khảo sát

% Chế độ chuẩn hóa nhiễu:
%   'EbN0'       : Eb tính cả năng lượng pilot và CP, giống chương trình chính.
%                  Thêm pilot làm tăng độ chính xác ước lượng nhưng tốn năng lượng.
%   'fixedNoise' : cùng phương sai nhiễu cho mọi Np (cùng SNR trên mỗi sóng mang),
%                  chỉ xét ảnh hưởng của số pilot lên độ chính xác ước lượng kênh.
noiseMode = 'EbN0';
EbRef = 0.0142;                     % Eb của cấu hình 16 pilot, dùng cho 'fixedNoise'

%% Mô phỏng
BER = zeros(numel(NpList), numel(EbN0dB));

for iNp = 1:numel(NpList)
    Np = NpList(iNp);
    rng(1);                         % Cùng chuỗi ngẫu nhiên cho mọi Np để so sánh công bằng

    % Rải đều Np pilot trên 52 sóng mang active
    pos = round(linspace(1, numel(activeIndices), Np));
    pilotIndices = activeIndices(pos);
    dataIndices = setdiff(activeIndices, pilotIndices, 'stable');
    pilotPattern = repmat([1; -1], ceil(Np/2), 1);
    pilotPattern = pilotPattern(1:Np);
    Ndata = numel(dataIndices);

    % Phát
    bitsTx = generate_ofdm_bits(Ndata, numOfdmSymbols, M);
    [~, ~, ~, ~, xCP] = ofdm_transmitter(bitsTx, NFFT, NCP, ...
        dataIndices, pilotIndices, pilotPattern);

    % Kênh Rayleigh 10 tap, block fading
    hChannel = sqrt(1/(2*Lh)) * (randn(Lh, numOfdmSymbols) + 1i*randn(Lh, numOfdmSymbols));
    rxChannel = zeros(NFFT + NCP, numOfdmSymbols);
    for m = 1:numOfdmSymbols
        y = conv(xCP(:, m), hChannel(:, m));
        rxChannel(:, m) = y(1:NFFT + NCP);
    end

    if strcmp(noiseMode, 'EbN0')
        Eb = sum(abs(xCP(:)).^2) / numel(bitsTx);
    else
        Eb = EbRef;
    end

    % Thu: thêm nhiễu, bỏ CP, FFT, ước lượng kênh, cân bằng ZF, giải ánh xạ
    for s = 1:numel(EbN0dB)
        N0 = Eb / 10^(EbN0dB(s)/10);
        rx = rxChannel + sqrt(N0/2) * (randn(size(rxChannel)) + 1i*randn(size(rxChannel)));
        Y = ofdm_fft(remove_cyclic_prefix(rx, NCP), NFFT);
        H_est = estimate_channel_ls(Y, pilotPattern, pilotIndices, NFFT);
        X_ZF = zf_equalizer(Y, H_est);
        bitsRx = qpsk_demodulate(X_ZF(dataIndices, :));
        BER(iNp, s) = mean(bitsRx(:) ~= bitsTx(:));
    end

    fprintf('Np = %2d, Ndata = %2d, BER tại 10 dB = %.4f, tại 20 dB = %.4f\n', ...
        Np, Ndata, BER(iNp, EbN0dB == 10), BER(iNp, EbN0dB == 20));
end

%% Bảng kết quả
disp(array2table([NpList(:) BER(:, EbN0dB == 0) BER(:, EbN0dB == 10) BER(:, EbN0dB == 20)], ...
    'VariableNames', {'Np', 'BER_0dB', 'BER_10dB', 'BER_20dB'}));

%% Hình 1: BER theo Eb/N0 cho từng số pilot
figure('Name', 'BER theo so pilot');
semilogy(EbN0dB, BER.', 'o-', 'LineWidth', 1.3);
grid on;
xlabel('E_b/N_0 (dB)');
ylabel('BER');
legend(compose('N_p = %d', NpList), 'Location', 'southwest');
title(sprintf('BER của nhánh ZF theo số pilot (chế độ %s)', noiseMode));

%% Hình 2: BER theo số pilot tại 10 dB và 20 dB
figure('Name', 'BER theo Np');
semilogy(NpList, BER(:, EbN0dB == 10), 's-', NpList, BER(:, EbN0dB == 20), 'd-', 'LineWidth', 1.3);
grid on;
xlabel('Số pilot N_p');
ylabel('BER');
legend('E_b/N_0 = 10 dB', 'E_b/N_0 = 20 dB', 'Location', 'best');
title(sprintf('BER theo số pilot (chế độ %s)', noiseMode));