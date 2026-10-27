clear;clc;
%% Thông tin cho bộ thu

% bitsTx: Bit gốc dùng để tính BER
% dataSymbols: Symbol QPSK gốc
% X: Symbol OFDM trong miền tấn số
% x: Symbol OFDM trong miền thời gian trước CP
% xCP / txSignal: Tín hiệu đi qua kênh truyền
% dataIndices: Vị trí subcarrier dữ liệu
% pilotIndices: Vị trí pilot
% nullIndices: Vị trí guard và DC
% pilotPattern: Các pilot mà bộ thu biết trước
% rxBlocksByEbN0: Tín hiệu đầu vào bộ thu
% HChannel Perfect CSI cho ZF/MMSE
% noiseVarianceTimeByEbN0: Phương sai dùng để tạo AWGN miền thời gian
% noiseVarianceFrequencyByEbN0: Phương sai dùng cho MMSE sau FFT
% EbN0dB: Trục hoành đồ thị BER

%% Bước 0: Khởi tạo tham số
clear; close all; clc;

% Thêm thư mục functions để script chạy được từ mọi thư mục hiện hành.
srcPath = fileparts(mfilename('fullpath'));
addpath(fullfile(srcPath, 'functions'));

% Khởi tạo bộ sinh số ngẫu nhiên khác nhau mỗi lần chạy.
rng("shuffle");

NFFT = 64; % Số điểm IFFT/FFT
NCP = 16; % Độ dài Cyclic Prefix
M = 4; % Bậc điều chế
numOfdmSymbols = 2000; % Số symbol OFDM mô phỏng
bitsPerQpskSymbol = log2(M); % Số bit trên một Symbol QPSK

% Thứ tự FFT gốc của MATLAB: DC nằm tại phần tử đầu tiên.
% <<<<<<< HEAD
% dataIndices = [2:7 9:15 17:19 21:23 25:27 39 41:43 45:47 49:51 53:55 57:59 61:64];
% pilotIndices = [4 8 12 16 20 24 40 44 48 52 56 60];
% =======
% >>>>>>> 5390aa06155f3a386f9d01fb9fc64f58fab17c67
nullIndices = [1 28:38];
activeIndices = [2:27 39:64];
pilotIndices = [2 5 9 12 16 19 22 26 40 44 47 50 54 57 61 64];
dataIndices = setdiff(activeIndices, pilotIndices, 'stable');
pilotPattern = [1; -1; 1; -1; 1; -1; 1; -1; ...
                1; -1; 1; -1; 1; -1; 1; -1];

Ndata = length(dataIndices); % số subcarrier dữ liệu
Npilot = length(pilotIndices); % số subcarrier pilot
Nnull = length(nullIndices); % số subcarrier null

% Thông số kênh và nhiễu
Lh = 10; % Số tap của kênh đa đường
EbN0dB = 0:2:20; % Miền Eb/N0 cần khảo sát

fprintf("------------------------- Bộ Phát(Tx) -------------------------");
%% Bước 1: Sinh dữ liệu bit
bitsTx = generate_ofdm_bits(Ndata, numOfdmSymbols, M);

%% Bước 2: Mô hình bộ phát OFDM
[txSignal, dataSymbols, X, x, xCP] = ofdm_transmitter(bitsTx, NFFT, NCP, dataIndices, pilotIndices, pilotPattern);

fprintf("\n------------------------- Tạo kênh truyền -------------------------\n");
%% Bước 3: Tạo kênh Rayleigh đa đường
hChannel = sqrt(1/(2*Lh)) * (randn(Lh, numOfdmSymbols) + 1i*randn(Lh,numOfdmSymbols));

% Giá trị trung bình của tổng công suất các tap phải gần bằng 1.
averageChannelPower = mean(sum(abs(hChannel).^2, 1));
fprintf('Công suất kênh trung bình = %.6f\n', averageChannelPower);

%% Bước 4: Truyền từng symbol qua kênh
samplesPerOfdmSymbol = NFFT + NCP;

rxChannel = zeros(samplesPerOfdmSymbol, numOfdmSymbols);
HChannel = zeros(NFFT, numOfdmSymbols);

for symbolIndex = 1:numOfdmSymbols
    h = hChannel(:, symbolIndex);

    % Tích chập tuyến tính giữa symbol có CP và kênh đa đường
    channelOutput = conv(xCP(:, symbolIndex), h);

    % Giữ lại phần có dùng chiều dài với symbol phát
    % Phần đuôi Lh - 1 mẫu không cho symbol đang xét
    rxChannel(:, symbolIndex) = channelOutput(1:samplesPerOfdmSymbol);
    HChannel(:, symbolIndex) = channel_frequency_response(h, NFFT); 
end

%% Bước 5: Tính năng lượng trên một bit
totalTransmitEnergy = sum(abs(xCP(:)).^2);
Eb = totalTransmitEnergy / length(bitsTx);

fprintf('Năng lượng trung bình trên một bit Eb = %.6e\n', Eb);

%% Bước 7: Cộng AWGN theo Eb/N0
numEbN0Points = length(EbN0dB);

%Lưu các tín hiệu thu để dùng cho bộ thu ở bước tiếp theo
rxBlocksByEbN0 = zeros(samplesPerOfdmSymbol, numOfdmSymbols, numEbN0Points);

noiseVarianceTimeByEbN0 = zeros(1, numEbN0Points);
noiseVarianceFrequencyByEbN0 = zeros(1, numEbN0Points);

for snrIndex = 1: numEbN0Points
    EbN0Linear = 10^(EbN0dB(snrIndex)/10);

    noiseVarianceTime = Eb / EbN0Linear;
    noiseVarianceTimeByEbN0(snrIndex) = noiseVarianceTime;

    noiseVarianceFrequencyByEbN0(snrIndex) = NFFT * noiseVarianceTime;

    noise = sqrt(noiseVarianceTime/2) * (randn(size(rxChannel)) + 1i*randn(size(rxChannel)));
    rxBlocksByEbN0(:, :, snrIndex) = rxChannel + noise;
end

fprintf("------------------------- Bộ Thu(Rx) -------------------------")
%% Bước 8: Bỏ CP và FFT cho từng giá trị Eb/N0
Y_fft = zeros(NFFT, numOfdmSymbols, numEbN0Points);

for snrIndex = 1:numEbN0Points
    rx_no_cp = remove_cyclic_prefix( ...
        rxBlocksByEbN0(:, :, snrIndex), NCP);
    Y_fft(:, :, snrIndex) = ofdm_fft(rx_no_cp, NFFT);
end

%% Bước 9: Ước lượng kênh từ pilot cho nhánh cân bằng giai đoạn 2
H_est = zeros(NFFT, numOfdmSymbols, numEbN0Points);

for snrIndex = 1:numEbN0Points
    H_est(:, :, snrIndex) = estimate_channel_ls_delay( ...
        Y_fft(:, :, snrIndex), pilotPattern, pilotIndices, NFFT, Lh);
end

%% Bước 10.1: Giải ánh xạ và tính BER giai đoạn 1 không cân bằng
BER_NoEQ = zeros(1, numEbN0Points);
bitErrorsNoEQ = zeros(1, numEbN0Points);
bitsRxNoEQAll = false(numel(bitsTx), numEbN0Points);

for snrIndex = 1:numEbN0Points
    % Chỉ giải ánh xạ các subcarrier dữ liệu, không cân bằng kênh.
    receivedDataSymbols = Y_fft(dataIndices, :, snrIndex);
    bitsRx = qpsk_demodulate(receivedDataSymbols);
    bitsRxNoEQAll(:, snrIndex) = bitsRx(:);

    % So sánh bit thu với bit phát để tính BER tại Eb/N0 hiện tại.
    bitErrorsNoEQ(snrIndex) = sum(bitsRx(:) ~= bitsTx(:));
    BER_NoEQ(snrIndex) = bitErrorsNoEQ(snrIndex) / numel(bitsTx);
end

fprintf('\nBER giai đoạn 1 - không cân bằng:\n');
disp(table(EbN0dB(:), bitErrorsNoEQ(:), BER_NoEQ(:), ...
    'VariableNames', {'EbN0_dB', 'SoBitLoi', 'BER_NoEQ'}));

%% Bước 10.2: Cân bằng ZF, giải ánh xạ và tính BER
BER_ZF = zeros(1, numEbN0Points);
bitErrorsZF = zeros(1, numEbN0Points);
bitsRxZFAll = false(numel(bitsTx), numEbN0Points);

for snrIndex = 1:numEbN0Points
    % Cân bằng bằng H ước lượng, sau đó chỉ lấy các subcarrier dữ liệu.
    X_ZF = zf_equalizer(Y_fft(:, :, snrIndex), H_est(:, :, snrIndex));
    receivedDataSymbolsZF = X_ZF(dataIndices, :);
    bitsRxZF = qpsk_demodulate(receivedDataSymbolsZF);
    bitsRxZFAll(:, snrIndex) = bitsRxZF(:);

    % Tính BER cho nhánh ZF tại Eb/N0 hiện tại.
    bitErrorsZF(snrIndex) = sum(bitsRxZF(:) ~= bitsTx(:));
    BER_ZF(snrIndex) = bitErrorsZF(snrIndex) / numel(bitsTx);
end

fprintf('\nBER giai đoạn 2 - cân bằng ZF:\n');
disp(table(EbN0dB(:), bitErrorsZF(:), BER_ZF(:), ...
    'VariableNames', {'EbN0_dB', 'SoBitLoi', 'BER_ZF'}));

%% Bước 10.3: Cân bằng MMSE, giải ánh xạ và tính BER
BER_MMSE = zeros(1, numEbN0Points);
bitErrorsMMSE = zeros(1, numEbN0Points);
bitsRxMMSEAll = false(numel(bitsTx), numEbN0Points);
symbolVariance = 1; % QPSK đã chuẩn hóa có công suất trung bình bằng 1.

for snrIndex = 1:numEbN0Points
    % Dùng phương sai nhiễu miền tần số sau FFT và kênh ước lượng LS.
    X_MMSE = mmse_equalizer( ...
        Y_fft(:, :, snrIndex), H_est(:, :, snrIndex), ...
        noiseVarianceFrequencyByEbN0(snrIndex), symbolVariance);
    receivedDataSymbolsMMSE = X_MMSE(dataIndices, :);
    bitsRxMMSE = qpsk_demodulate(receivedDataSymbolsMMSE);
    bitsRxMMSEAll(:, snrIndex) = bitsRxMMSE(:);

    % Tính BER cho nhánh MMSE tại Eb/N0 hiện tại.
    bitErrorsMMSE(snrIndex) = sum(bitsRxMMSE(:) ~= bitsTx(:));
    BER_MMSE(snrIndex) = bitErrorsMMSE(snrIndex) / numel(bitsTx);
end

fprintf('\nBER giai đoạn 2 - cân bằng MMSE:\n');
disp(table(EbN0dB(:), bitErrorsMMSE(:), BER_MMSE(:), ...
    'VariableNames', {'EbN0_dB', 'SoBitLoi', 'BER_MMSE'}));

%% DEBUG: Kiem tra BER voi Perfect CSI
BER_PerfectCSI = zeros(1, numEbN0Points);

for snrIndex = 1:numEbN0Points

    % Can bang voi dap ung kenh CHINH XAC
    X_perfect = Y_fft(:,:,snrIndex) ./ HChannel;

    % Chi lay cac subcarrier du lieu
    dataPerfect = X_perfect(dataIndices,:);

    % Giai dieu che QPSK
    bitsPerfect = qpsk_demodulate(dataPerfect);

    % Tinh BER
    BER_PerfectCSI(snrIndex) = ...
        sum(bitsPerfect(:) ~= bitsTx(:)) / numel(bitsTx);
end

% So sanh 4 phuong phap
figure;
semilogy(EbN0dB, max(BER_NoEQ, 1e-6), 'k-o'); hold on;
semilogy(EbN0dB, max(BER_ZF, 1e-6), 'r-s');
semilogy(EbN0dB, max(BER_MMSE, 1e-6), 'b-d');
semilogy(EbN0dB, max(BER_PerfectCSI, 1e-6), 'g-^');

grid on;
xlabel('Eb/N0 (dB)');
ylabel('BER');
title('Kiem tra BER voi Perfect CSI');
legend('No EQ','ZF-LS','MMSE-LS', ...
       'Perfect CSI','Location','southwest');

disp(table(EbN0dB(:), BER_ZF(:), ...
    BER_MMSE(:), BER_PerfectCSI(:), ...
    'VariableNames', ...
    {'EbN0_dB','ZF','MMSE','PerfectCSI'}));

%% Tính BER với 8 pilot bằng nội suy đáp ứng tần số
pilotIndices8 = pilotIndices(1:2:end);
pilotPattern8 = pilotPattern(1:2:end);
dataIndices8 = setdiff(activeIndices, pilotIndices8, 'stable');
Ndata8 = length(dataIndices8);
bitsTx8 = generate_ofdm_bits(Ndata8, numOfdmSymbols, M);

[~, ~, ~, ~, xCP8] = ofdm_transmitter( ...
    bitsTx8, NFFT, NCP, dataIndices8, pilotIndices8, pilotPattern8);

rxChannel8 = zeros(samplesPerOfdmSymbol, numOfdmSymbols);
for symbolIndex = 1:numOfdmSymbols
    channelOutput8 = conv(xCP8(:, symbolIndex), hChannel(:, symbolIndex));
    rxChannel8(:, symbolIndex) = channelOutput8(1:samplesPerOfdmSymbol);
end

Eb8 = sum(abs(xCP8(:)).^2) / numel(bitsTx8);
BER_ZF_8Pilot = zeros(1, numEbN0Points);
BER_MMSE_8Pilot = zeros(1, numEbN0Points);
interpolationIndices = [pilotIndices8 - NFFT, pilotIndices8, ...
    pilotIndices8 + NFFT];
interpolationIndices = interpolationIndices(:);

for snrIndex = 1:numEbN0Points
    noiseVarianceTime8 = Eb8 / 10^(EbN0dB(snrIndex)/10);
    noise8 = sqrt(noiseVarianceTime8/2) * ...
        (randn(size(rxChannel8)) + 1i*randn(size(rxChannel8)));
    rxNoisy8 = rxChannel8 + noise8;
    rxNoCP8 = remove_cyclic_prefix(rxNoisy8, NCP);
    Y_fft8 = ofdm_fft(rxNoCP8, NFFT);

    pilotResponse8 = Y_fft8(pilotIndices8, :) ./ pilotPattern8(:);
    H_est8 = interp1( ...
        interpolationIndices, ...
        [pilotResponse8; pilotResponse8; pilotResponse8], ...
        (1:NFFT).', 'linear');

    X_ZF_8Pilot = zf_equalizer(Y_fft8, H_est8);
    bitsRxZF8 = qpsk_demodulate(X_ZF_8Pilot(dataIndices8, :));
    BER_ZF_8Pilot(snrIndex) = ...
        sum(bitsRxZF8(:) ~= bitsTx8(:)) / numel(bitsTx8);

    noiseVarianceFrequency8 = NFFT * noiseVarianceTime8;
    X_MMSE_8Pilot = mmse_equalizer( ...
        Y_fft8, H_est8, noiseVarianceFrequency8, symbolVariance);
    bitsRxMMSE8 = qpsk_demodulate(X_MMSE_8Pilot(dataIndices8, :));
    BER_MMSE_8Pilot(snrIndex) = ...
        sum(bitsRxMMSE8(:) ~= bitsTx8(:)) / numel(bitsTx8);
end

%% Vẽ đồ thị
symbolToPlot = 1;
EbN0ToPlot = 10;

[~, snrIndexToPlot] = min(abs(EbN0dB - EbN0ToPlot));
rxBlocksToPlot = rxBlocksByEbN0(:, :, snrIndexToPlot);

%% Hình 1: Chòm sao QPSK tại bộ phát
qpskVector = dataSymbols(:);
numQpskToPlot = min(2000, length(qpskVector));

figure('Name', 'Chòm sao QPSK tại bộ phát');
scatter(real(qpskVector(1:numQpskToPlot)), imag(qpskVector(1:numQpskToPlot)), 24, 'filled');
grid on;
axis equal;
xlim([-1.2 1.2]);
ylim([-1.2 1.2]);
xlabel('In-phase');
ylabel('Quadrature');
title('Chòm sao QPSK tại bộ phát');

%% Hình 2: Phân bố subcarrier
subcarrierAxis = -NFFT/2:NFFT/2-1;
Xcentered = fftshift(X, 1);

dataMask = false(NFFT, 1);
pilotMask = false(NFFT, 1);
nullMask = false(NFFT, 1);

dataMask(dataIndices) = true;
pilotMask(pilotIndices) = true;
nullMask(nullIndices) = true;

dataMask = fftshift(dataMask);
pilotMask = fftshift(pilotMask);
nullMask = fftshift(nullMask);

figure('Name', 'Phân bố subcarrier');

stem(subcarrierAxis(dataMask), abs(Xcentered(dataMask, symbolToPlot)),'g', 'filled', 'LineWidth', 1.1);
hold on;
stem(subcarrierAxis(pilotMask), abs(Xcentered(pilotMask, symbolToPlot)), 'b', 'filled', 'LineWidth', 1.5);
stem(subcarrierAxis(nullMask), abs(Xcentered(nullMask, symbolToPlot)), 'r', 'LineWidth', 1.0);

grid on;
xlim([-NFFT/2 NFFT/2-1]);
xlabel('Chỉ số subcarrier k');
ylabel('|X[k]|');
title(sprintf( 'Phân bố subcarrier của symbol OFDM thứ %d', symbolToPlot));
legend('Data', 'Pilot', 'Null/DC', 'Location', 'best');

%% Hình 3: Symbol OFDM có CP
xCpSelected = xCP(:, symbolToPlot);
sampleAxisWithCP = -NCP:NFFT-1;

figure('Name', 'Symbol OFDM có CP');

plot(sampleAxisWithCP(1:NCP), real(xCpSelected(1:NCP)), 'r-o', 'LineWidth', 1.3, 'MarkerSize', 4);
hold on;
plot(sampleAxisWithCP(NCP+1:end), real(xCpSelected(NCP+1:end)), 'b-o', 'LineWidth', 1.0, 'MarkerSize', 3);
xline(-0.5, 'k--', 'Ranh giới CP');
grid on;
xlabel('Chỉ số mẫu tương đối');
ylabel('Phần thực');
title('Symbol OFDM gồm CP và phần dữ liệu hữu ích');
legend('Cyclic Prefix', 'NFFT mẫu hữu ích', 'Location', 'best');

%% Hình 4: Phổ chuẩn hóa của tín hiệu phát
nSpectrum = 8192;
txSpectrum = fftshift(fft(txSignal, nSpectrum));
txSpectrumDb = 20*log10(abs(txSpectrum) / max(abs(txSpectrum)) + eps);
normalizedFrequency = (-nSpectrum/2:nSpectrum/2-1) / nSpectrum;

figure('Name', 'Phổ tín hiệu OFDM');
plot(normalizedFrequency, txSpectrumDb, 'LineWidth', 1.0);
grid on;
xlim([-0.5 0.5]);
ylim([-80 5]);
xlabel('Tần số chuẩn hóa f/F_s');
ylabel('Biên độ chuẩn hóa (dB)');
title('Phổ của chuỗi tín hiệu OFDM tại bộ phát');

%% Hình bổ sung: Công suất tức thời và PAPR
instantaneousPower = abs(x(:)).^2;
averageTxPower = mean(instantaneousPower);
peakTxPower = max(instantaneousPower);

paprDb = 10*log10(peakTxPower/averageTxPower);

numPowerSamplesToPlot = min(1000, length(x(:)));

figure('Name', 'Công suất tức thời');
plot(0:numPowerSamplesToPlot-1, instantaneousPower(1:numPowerSamplesToPlot), 'b', 'LineWidth', 1.0);
hold on;
yline(averageTxPower, 'r--', 'Công suất trung bình');
grid on;
xlabel('Chỉ số mẫu');
ylabel('|x[n]|^2');
title(sprintf('Công suất tức thời, PAPR = %.2f dB', paprDb));

%% Hình 5: Đáp ứng xung của kênh đa đường
hSelected = hChannel(:, symbolToPlot);
tapAxis = 0:Lh-1;

figure('Name', 'Đáp ứng xung kênh');
tiledlayout(2, 1);

nexttile;
stem(tapAxis, abs(hSelected), 'filled', 'LineWidth', 1.2);
grid on;
xlabel('Chỉ số tap l');
ylabel('|h[l]|');
title('Biên độ đáp ứng xung kênh đa đường');

nexttile;
stem(tapAxis, angle(hSelected),'filled', 'LineWidth', 1.2);
grid on;
xlabel('Chỉ số tap l');
ylabel('Pha (rad)');
title('Pha của các tap kênh');

%% Hình 6: Đáp ứng tần số của kênh
HSelected = HChannel(:, symbolToPlot);
HCentered = fftshift(HSelected);
normalizedFrequency = (-NFFT/2:NFFT/2-1) / NFFT;

figure('Name', 'Đáp ứng tần số kênh');
tiledlayout(2, 1);

nexttile;
plot(normalizedFrequency, 20*log10(abs(HCentered) + eps), ...
    'b-o', 'LineWidth', 1.1, 'MarkerSize', 3);
grid on;
xlabel('Tần số chuẩn hóa f/F_s');
ylabel('|H(f)| (dB)');
title('Đáp ứng biên độ của kênh');

nexttile;
plot(normalizedFrequency, unwrap(angle(HCentered)), ...
    'r-o', 'LineWidth', 1.1, 'MarkerSize', 3);
grid on;
xlabel('Tần số chuẩn hóa f/F_s');
ylabel('Pha (rad)');
title('Đáp ứng pha của kênh');

%% Hình 7: So sánh trước và sau kênh
txBlockSelected = xCP(:, symbolToPlot);
rxChannelSelected = rxChannel(:, symbolToPlot);
rxNoisySelected = rxBlocksToPlot(:, symbolToPlot);

sampleAxis = 0:length(txBlockSelected)-1;

figure('Name', 'Ảnh hưởng của kênh');
tiledlayout(3, 1);

nexttile;
plot(sampleAxis, real(txBlockSelected), 'b', 'LineWidth', 1.0);
grid on;
ylabel('Re\{x_{CP}[n]\}');
title('Tín hiệu phát');

nexttile;
plot(sampleAxis, real(rxChannelSelected), 'm', 'LineWidth', 1.0);
grid on;
ylabel('Re\{y[n]\}');
title('Sau kênh đa đường, chưa có AWGN');

nexttile;
plot(sampleAxis, real(rxNoisySelected), 'r', 'LineWidth', 1.0);
grid on;
xlabel('Chỉ số mẫu');
ylabel('Re\{r[n]\}');
title(sprintf('Sau kênh và AWGN tại E_b/N_0 = %.1f dB', EbN0dB(snrIndexToPlot)));

%% Hình 8: Chòm sao trước cân bằng
rxNoCPToPlot = remove_cyclic_prefix(rxBlocksToPlot, NCP);

YToPlot = ofdm_fft(rxNoCPToPlot, NFFT);
receivedDataBeforeEqualization = YToPlot(dataIndices, :);

receivedVector = receivedDataBeforeEqualization(:);
numReceivedToPlot = min(3000, length(receivedVector));

figure('Name', 'Chòm sao trước cân bằng');
scatter(real(receivedVector(1:numReceivedToPlot)), imag(receivedVector(1:numReceivedToPlot)),10,'filled');
grid on;
axis equal;
xlabel('In-phase');
ylabel('Quadrature');
title(sprintf('Chòm sao sau kênh, trước cân bằng tại E_b/N_0 = %.1f dB', EbN0dB(snrIndexToPlot)));

%% Hình 9: Chòm sao sau cân bằng ZF và MMSE
YToEqualize = Y_fft(:, :, snrIndexToPlot);
HEstToPlot = H_est(:, :, snrIndexToPlot);

XZFToPlot = zf_equalizer(YToEqualize, HEstToPlot);
dataSymbolsZFToPlot = XZFToPlot(dataIndices, :);
vectorZFToPlot = dataSymbolsZFToPlot(:);
numZFToPlot = min(3000, numel(vectorZFToPlot));

XMMSEToPlot = mmse_equalizer( ...
    YToEqualize, HEstToPlot, ...
    noiseVarianceFrequencyByEbN0(snrIndexToPlot), symbolVariance);
dataSymbolsMMSEToPlot = XMMSEToPlot(dataIndices, :);
vectorMMSEToPlot = dataSymbolsMMSEToPlot(:);
numMMSEToPlot = min(3000, numel(vectorMMSEToPlot));

figure('Name', 'Chom sao sau can bang');
tiledlayout(1, 2);

nexttile;
scatter(real(vectorZFToPlot(1:numZFToPlot)), ...
    imag(vectorZFToPlot(1:numZFToPlot)), 10, 'filled');
grid on;
axis equal;
xlabel('In-phase');
ylabel('Quadrature');
title(sprintf('Sau cân bằng ZF, E_b/N_0 = %.1f dB', ...
    EbN0dB(snrIndexToPlot)));

nexttile;
scatter(real(vectorMMSEToPlot(1:numMMSEToPlot)), ...
    imag(vectorMMSEToPlot(1:numMMSEToPlot)), 10, 'filled');
grid on;
axis equal;
xlabel('In-phase');
ylabel('Quadrature');
title(sprintf('Sau cân bằng MMSE, E_b/N_0 = %.1f dB', ...
    EbN0dB(snrIndexToPlot)));

%% Đồ thị so sánh BER ba phương án thu
figure('Name', 'So sanh BER OFDM');
semilogy(EbN0dB, BER_NoEQ, 'o-', 'LineWidth', 1.5);
hold on;
semilogy(EbN0dB, BER_ZF, 's-', 'LineWidth', 1.5);
semilogy(EbN0dB, BER_MMSE, 'd-', 'LineWidth', 1.5);
grid on;
xlabel('E_b/N_0 (dB)');
ylabel('BER');
title('So sánh BER OFDM: không cân bằng, ZF và MMSE');
legend('Không cân bằng', 'ZF', 'MMSE', 'Location', 'southwest');

%% Hình bổ sung: So sánh BER với 8 và 16 pilot
figure('Name', 'So sánh BER 8 pilot và 16 pilot');
semilogy(EbN0dB, BER_ZF, 'bo-', 'LineWidth', 1.5);
hold on;
semilogy(EbN0dB, BER_MMSE, 'bs-', 'LineWidth', 1.5);
semilogy(EbN0dB, BER_ZF_8Pilot, 'r^-', 'LineWidth', 1.5);
semilogy(EbN0dB, BER_MMSE_8Pilot, 'rd-', 'LineWidth', 1.5);
grid on;
xlabel('E_b/N_0 (dB)');
ylabel('BER');
title('So sánh BER với 8 pilot và 16 pilot');
legend('ZF - 16 pilot', 'MMSE - 16 pilot', ...
    'ZF - 8 pilot', 'MMSE - 8 pilot', 'Location', 'southwest');

%% Hình cuối: So sánh chuỗi bit tại Eb/N0 = 10 dB và 20 dB
numBitsToPlot = min(100, numel(bitsTx));
bitIndicesToPlot = 1:numBitsToPlot;
bitsTxToPlot = double(bitsTx(1:numBitsToPlot).');
methodNames = {'Không cân bằng', 'ZF', 'MMSE'};
EbN0BitPlots = [10 20];

for plotIndex = 1:numel(EbN0BitPlots)
    [~, bitPlotSNRIndex] = min(abs(EbN0dB - EbN0BitPlots(plotIndex)));
    receivedBitSequences = {
        bitsRxNoEQAll(1:numBitsToPlot, bitPlotSNRIndex), ...
        bitsRxZFAll(1:numBitsToPlot, bitPlotSNRIndex), ...
        bitsRxMMSEAll(1:numBitsToPlot, bitPlotSNRIndex)};

    figure('Name', sprintf('So sanh bit tai EbN0 %d dB', ...
        EbN0BitPlots(plotIndex)));
    tiledlayout(3, 1);

    for methodIndex = 1:numel(methodNames)
        bitsReceivedToPlot = double(receivedBitSequences{methodIndex}(:).');
        errorIndices = bitIndicesToPlot(bitsReceivedToPlot ~= bitsTxToPlot);

        nexttile;
        stairs(bitIndicesToPlot, bitsTxToPlot, 'k--', 'LineWidth', 1.0);
        hold on;
        stairs(bitIndicesToPlot, bitsReceivedToPlot, 'b-', 'LineWidth', 1.2);
        plot(errorIndices, 1.15 * ones(size(errorIndices)), ...
            'rx', 'LineWidth', 1.5, 'MarkerSize', 7);
        grid on;
        ylim([-0.2 1.3]);
        xlabel('Chỉ số bit');
        ylabel('Giá trị bit');
        title(sprintf('Bit gốc và bit thu - %s, E_b/N_0 = %.1f dB', ...
            methodNames{methodIndex}, EbN0dB(bitPlotSNRIndex)));
        legend('Bit phát', 'Bit thu', 'Location', 'eastoutside');
    end
end
