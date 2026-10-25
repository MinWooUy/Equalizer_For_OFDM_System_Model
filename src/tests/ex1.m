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

%% Bước 0: Khởi tạo tham số
clear; close all; clc;

% Thêm thư mục functions để script chạy được từ mọi thư mục hiện hành.
srcPath = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(srcPath, 'functions'));

% Cố định bộ sinh số ngẫu nhiên để có thể lặp lại kết quả.
rng(1);

NFFT = 64; % Số điểm IFFT/FFT
NCP = 16; % Độ dài Cyclic Prefix
M = 4; % Bậc điều chế
bitsPerQpskSymbol = log2(M); % Số bit trên một Symbol QPSK

% Thứ tự FFT gốc của MATLAB: DC nằm tại phần tử đầu tiên.
dataIndices = [2:7 9:21 23:27 39:43 45:57 59:64];
pilotIndices = [8 22 44 58];
nullIndices = [1 28:38];
pilotPattern = [1; -1; 1; 1];

Ndata = length(dataIndices); % số subcarrier dữ liệu
Npilot = length(pilotIndices); % số subcarrier pilot
Nnull = length(nullIndices); % số subcarrier null

%% Bước 1: Sinh chuỗi bit
numBitsPerOfdmSymbol = Ndata*bitsPerQpskSymbol;
numOfdmSymbols = 1000;
bitsTx = generate_ofdm_bits(Ndata, numOfdmSymbols, M);

%% Bước 2 - 6: Thực hiện các chức năng của bộ phát OFDM
[txSignal, dataSymbols, X, x, xCP] = ofdm_transmitter( ...
    bitsTx, NFFT, NCP, dataIndices, pilotIndices, pilotPattern);

txPowerWithoutCp = mean(abs(x(:)).^2); % Công suất tín hiệu

%% Quan sát hình ảnh

% Cấu hình chung
symbolToPlot = 1; % Symbol OFDM được chọn
qpskVector = dataSymbols(:);
numQpskToPlot = min(2000, length(qpskVector)); % Số điểm QPSK hiển thị
numTimeSymbolsToPlot = 3;

% Quan sát bit đầu vào
numBitsToPlot = 40;
bitsSub = bitsTx(1:numBitsToPlot);

figure('Name', 'Dữ liệu bit đầu vào'); 
t = 0:numBitsToPlot;
b = [bitsSub; bitsSub(end)];
grid on; hold on;
stairs(t, b, 'LineWidth', 1.5, 'color', [0 0.447 0.741]);
stem(0:numBitsToPlot-1, bitsTx(1:numBitsToPlot), 'filled', 'LineWidth', 1.2);
ylim([-0.2 1.2]);
xlim([0 numBitsToPlot]);
xlabel('Chỉ số bit');
ylabel('Biên độ');
title(sprintf('%d bit đầu tiên tại bộ phát', numBitsToPlot));

% Bản đồ chòm sao QPSK
figure('Name', 'Chòm sao QPSK'); 
scatter(real(qpskVector(1:numQpskToPlot)), imag(qpskVector(1:numQpskToPlot)), 24, 'filled');
grid on;
axis equal;
xlim([-1.2 1.2]);
ylim([-1.2 1.2]);
xlabel('In-phase');
ylabel('Quadrature');
title('Chòm sao QPSK tại bộ phát');

% Lưới Subcarrier của một symbol OFDM
Xcentered = fftshift(X, 1);
subcarrierAxis = -NFFT/2:NFFT/2-1;

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
stem(subcarrierAxis(dataMask), ...
    abs(Xcentered(dataMask, symbolToPlot)), ...
    'g', 'filled','LineWidth', 1.1);
hold on;
stem(subcarrierAxis(pilotMask), ...
    abs(Xcentered(pilotMask, symbolToPlot)), ...
    'b', 'filled', 'Linewidth', 1.5);
stem(subcarrierAxis(nullMask), ...
    abs(Xcentered(nullMask, symbolToPlot)), ...
    'r', 'LineWidth', 1.0);
grid on;
xlabel('Chỉ số subcarrier k');
ylabel('|X[k]|');
title(sprintf('Phân bố subcarrier của symbol OFDM thứ %d', symbolToPlot));
legend('Data', 'Pilot', 'Null/DC', 'Location', 'best');

% Phổ subcarrier đã dịch
figure('Name', 'Phổ subcarrier đã dịch');
stem(subcarrierAxis, ...
    abs(Xcentered(:, symbolToPlot)), ...
    'filled', 'LineWidth', 1.0);
grid on;
xlabel('Chỉ số subcarrier tương đối');
ylabel('|X[k]|');
title('Symbol OFDM trong miền tần số');

% Một symbol OFDM trong miền thời gian
n = 0:NFFT-1;
xSelected = x(:, symbolToPlot);

figure('Name', 'Symbol OFDM miền thời gian');
tiledlayout(3,1);

nexttile;
plot(n, real(xSelected), 'b-o', 'LineWidth', 1.0, 'MarkerSize', 3);
grid on;
xlabel('Chỉ số mẫu n');
ylabel('Re\{x[n]\}');
title('Thành phần thực');

nexttile;
plot(n, imag(xSelected), 'r-o', 'LineWidth', 1.0, 'MarkerSize', 3);
grid on;
xlabel('Chỉ số mẫu n');
ylabel('Im\{x[n]\}');
title('Thành phần ảo');

nexttile;
stem(n, abs(xSelected), 'filled', 'LineWidth', 1.0);
grid on;
xlabel('Chỉ số mẫu n');
ylabel('|x[n]|');
title('Biên độ symbol OFDM');

% Đồ thị symbol OFDM sau khi chèn CP
xCpSelected = xCP(:, symbolToPlot);
nCp = -NCP : NFFT-1;

figure('Name', 'Cyclic Prefix');
plot(nCp(1:NCP), real(xCpSelected(1:NCP)), 'r-o', 'LineWidth', 1.4, 'MarkerSize', 4);
hold on;
plot(nCp(NCP+1:end), real(xCpSelected(NCP+1:end)), 'b-o', 'LineWidth',1.0, 'MarkerSize', 3);
xline(-0.5, 'w--', 'Ranh giới CP');
grid on;
xlabel('Chỉ số mẫu tương đối');
ylabel('Phần thực');
title('Symbol OFDM gồm CP và phần dữ liệu hữu ích');
legend('Cyclic Prefix', '64 mẫu hữu ích', 'Location', 'best');

% So sánh CP với đuôi symbol
cpSelected = xCP(1:NCP, symbolToPlot);
tailSelected = x(end-NCP+1:end, symbolToPlot);
figure('Name', 'So sánh Cyclic Prefix và đuôi symbol');
plot(0:NCP-1, real(cpSelected), 'r-o', 'LineWidth', 1.3);
hold on;
plot(0:NCP-1, real(tailSelected), 'b--s', 'LineWidth', 1.1);
grid on;
xlabel('Chỉ số trong CP');
ylabel('Phần thực');
title('So sánh CP với NCP mẫu cuối của symbol OFDM');
legend('Cyclic Prefix', 'Đuôi symbol gốc', 'Location', 'best');

% Chuỗi phát nối tiếp
samplePerOfdmSymbol = NFFT + NCP;
numSamplesToPlot = numTimeSymbolsToPlot * samplePerOfdmSymbol;

figure('Name', 'Chuỗi phát OFDM');
plot(0:numSamplesToPlot-1, real(txSignal(1:numSamplesToPlot)), 'b', 'LineWidth', 1.0);
hold on;

for symbolIndex = 1:numTimeSymbolsToPlot-1
    boundary = symbolIndex * samplePerOfdmSymbol - 0.5;
    xline(boundary, 'r--');
end

grid on;
xlabel('Chỉ số mẫu n');
ylabel('Re\{Tx_Signal[n]\}');
title(sprintf('%d symbol OFDM liên tiếp, mỗi symbol gồm %d mẫu', numTimeSymbolsToPlot, samplePerOfdmSymbol));

% Phổ chuẩn hóa của tín hiệu phát
nSpectrum = 8192;
txSpectrum = fftshift(fft(txSignal, nSpectrum));
txSpectrumDb = 20*log10(abs(txSpectrum)/max(abs(txSpectrum)) + eps);
normalizedFrequency = (-nSpectrum/2:nSpectrum/2-1) / nSpectrum;

figure('Name', 'Phổ tín hiệu OFDM');
plot(normalizedFrequency, txSpectrumDb, 'LineWidth', 1.2);
grid on;
ylim([-80 5]);
xlabel('Tần số chuẩn hóa f/F_s');
ylabel('Biên độ chuẩn hóa (dB)');
title('Phổ của chuỗi tín hiệu OFDM tại bộ phát');

% Công suất tức thời và PAPR
instantaneousPower = abs(txSignal).^2;
averageTxPower = mean(instantaneousPower);
peakTxPower = max(instantaneousPower);
paprDb = 10*log10(peakTxPower / averageTxPower);

fprintf('Công suất phát trung bình = %.6e\n', averageTxPower);
fprintf('Công suất phát đỉnh = %.6e\n', peakTxPower);
fprintf('PAPR = %.3f dB\n', paprDb);

numPowerSamplesToPlot = min(1000, length(txSignal));

figure('Name', 'Công suất tức thời');
plot(0:numPowerSamplesToPlot-1, instantaneousPower(1:numPowerSamplesToPlot),'b', 'LineWidth', 1.0);
hold on;
yline(averageTxPower, 'r--', 'Công suất trung bình', 'LineWidth', 1.3);
grid on;
xlabel('Chỉ số mẫu');
ylabel('|TxSignal[n]|^2');
title(sprintf('Công suất tức thời, PAPR = %.2f dB', paprDb));
%% Quan sát số liệu
averageQpskPower = mean(abs(dataSymbols(:)).^2);
fprintf('Công suất QPSK trung bình = %.6f\n', averageQpskPower);

ratioOfOnes = mean(bitsTx);
fprintf('Tỷ lệ bit 1 = %.4f\n', ratioOfOnes);

cpError = max(abs(cpSelected - tailSelected));
fprintf('Sai số sao chép CP = %.3e\n', cpError);

%% Kiểm tra tương thích với các hàm bộ thu

% Trường hợp lý tưởng: không có kênh đa đường và không có nhiễu.
rxNoCP = remove_cyclic_prefix(xCP, NCP);
Y = ofdm_fft(rxNoCP, NFFT);
dataSymbolsRx = Y(dataIndices, :);
bitsRx = qpsk_demodulate(dataSymbolsRx);

ifftFftError = max(abs(Y(:) - X(:)));
berLoopback = mean(bitsRx(:) ~= bitsTx);

fprintf('Sai số lớn nhất của FFT(IFFT(X)) = %.3e\n', ifftFftError);
fprintf('BER vòng lặp phát-thu lý tưởng = %.3e\n', berLoopback);

assert(abs(averageQpskPower - 1) < 1e-12);
assert(cpError < 1e-12);
assert(ifftFftError < 1e-10);
assert(berLoopback == 0);

