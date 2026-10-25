# Cân bằng cho hệ thống OFDM qua kênh đa đường

## 1. Mục tiêu

Mô phỏng một hệ thống OFDM truyền qua kênh fading đa đường có nhiễu AWGN, sau đó so sánh ba phương án xử lý tại phía thu:

1. Không sử dụng bộ cân bằng.
2. Sử dụng bộ cân bằng Zero-Forcing (ZF).
3. Sử dụng bộ cân bằng Minimum Mean Square Error (MMSE).

Hiệu năng của ba phương án được đánh giá chủ yếu bằng BER theo `Eb/N0`. Các kết quả bổ sung gồm giản đồ chòm sao và đáp ứng tần số của kênh. Từ đó phân tích ưu, nhược điểm của ZF và MMSE trong kênh fading chọn lọc tần số.

## 2. Phạm vi

### 2.1. Phạm vi bắt buộc

- Hệ thống SISO-OFDM băng gốc phức.
- Điều chế QPSK, ánh xạ Gray, công suất symbol trung bình được chuẩn hóa bằng 1.
- Điều chế/giải điều chế OFDM bằng IFFT/FFT.
- Cyclic Prefix (CP) đủ dài để bao phủ bộ nhớ kênh.
- Kênh fading đa đường tuyến tính, biến đổi chậm theo từng symbol OFDM.
- Nhiễu AWGN phức.
- So sánh công bằng ba trường hợp: không cân bằng, ZF và MMSE trên cùng dữ liệu, cùng hiện thực kênh và cùng mẫu nhiễu.
- Giả sử phía thu biết chính xác đáp ứng kênh (perfect CSI) để tập trung đánh giá riêng ảnh hưởng của thuật toán cân bằng.

### 2.2. Hướng mở rộng giai đoạn 2

- Ước lượng kênh bằng pilot và nội suy thay cho perfect CSI.
- So sánh ảnh hưởng của sai số ước lượng kênh lên BER sau cân bằng.

### 2.3. Ngoài phạm vi

- Sai lệch tần số sóng mang, sai lệch thời gian và ICI.
- Mô hình bộ khuếch đại phi tuyến và PAPR reduction.
- Mã hóa kênh, interleaving, MIMO và OFDMA.

Các nội dung này có thể được thực hiện sau khi mô hình bắt buộc đã chạy đúng.

## 3. Mô hình hệ thống

### 3.1. Chuỗi xử lý

```text
BỘ PHÁT
Bits
  -> QPSK mapping
  -> Ánh xạ data/pilot/null lên các subcarrier
  -> IFFT
  -> Chèn CP
  -> Tín hiệu phát

KÊNH TRUYỀN
Tích chập với đáp ứng kênh đa đường h[n]
  -> Cộng nhiễu AWGN

BỘ THU
Loại bỏ CP
  -> FFT
  -> Tạo ba nhánh: không cân bằng / ZF / MMSE
  -> Lấy các subcarrier dữ liệu
  -> QPSK demapping
  -> So sánh bit và tính BER
```

Lưu ý: phía thu phải loại bỏ CP trước khi thực hiện FFT.

### 3.2. Mô hình miền thời gian

Tín hiệu thu được mô hình hóa bởi

```math
r[n] = h[n] * x_{cp}[n] + w[n],
```

trong đó:

- `x_cp[n]` là symbol OFDM sau khi chèn CP;
- `h[n]` là đáp ứng xung của kênh đa đường;
- `w[n]` là nhiễu AWGN phức;
- `*` là phép tích chập tuyến tính.

Điều kiện CP:

```math
N_{CP} \ge L_h - 1,
```

với `L_h` là số tap của kênh. Khi điều kiện này và điều kiện đồng bộ được thỏa mãn, sau khi bỏ CP và FFT ta có mô hình trên từng subcarrier:

```math
Y[k] = H[k]X[k] + W[k].
```

## 4. Các phương án tại bộ thu

### 4.1. Không cân bằng

Không bù đáp ứng kênh:

```math
\hat{X}_{NoEQ}[k] = Y[k].
```

Nhánh này là đường cơ sở để quan sát ảnh hưởng của suy hao biên độ và xoay pha do kênh đa đường.

### 4.2. Zero-Forcing

```math
W_{ZF}[k] = \frac{1}{H[k]},
```

```math
\hat{X}_{ZF}[k] = \frac{Y[k]}{H[k]}.
```

Khi cài đặt cần tránh chia trực tiếp cho giá trị quá gần 0. Có thể dùng dạng số ổn định:

```matlab
Xhat_ZF = Y .* conj(H) ./ (abs(H).^2 + eps);
```

ZF khử méo tuyến tính của kênh nhưng có thể khuếch đại mạnh nhiễu tại các subcarrier bị deep fading.

Hàm `zf_equalizer` nhận tín hiệu sau FFT `Y` và đáp ứng kênh ước lượng `H_est`:

```matlab
X_est = zf_equalizer(Y, H_est);
```

Sau cân bằng, lấy các hàng dữ liệu theo `data_indices` rồi giải ánh xạ QPSK Gray:

```matlab
data_symbols = X_est(data_indices, :);
bits_est = qpsk_demodulate(data_symbols);
```

`bits_est` có `2 * số_subcarrier_dữ_liệu` hàng; mỗi cột là bit của một symbol OFDM, với từng cặp bit theo thứ tự Gray.

### 4.3. MMSE

```math
W_{MMSE}[k]
= \frac{H^*[k]}{|H[k]|^2 + \sigma_w^2/\sigma_x^2},
```

```math
\hat{X}_{MMSE}[k] = W_{MMSE}[k]Y[k].
```

Với symbol dữ liệu được chuẩn hóa `sigma_x^2 = 1`, mẫu số trở thành `|H[k]|^2 + sigma_w^2`. MMSE chấp nhận một lượng sai lệch nhỏ để hạn chế khuếch đại nhiễu, do đó thường tốt hơn ZF ở SNR thấp và tại các subcarrier bị suy hao sâu.

Hàm `mmse_equalizer` nhận tín hiệu sau FFT, kênh ước lượng, phương sai nhiễu AWGN và công suất trung bình symbol phát:

```matlab
X_est = mmse_equalizer(Y, H_est, noise_variance, symbol_variance);
```

Với QPSK chuẩn hóa công suất trung bình bằng 1, đặt `symbol_variance = 1`.

### 4.4. Ước lượng kênh LS bằng pilot (giai đoạn 2)

Tại các vị trí pilot đã biết, ước lượng đáp ứng kênh bằng:

```math
\hat{H}_{LS}[k_p] = \frac{Y[k_p]}{X_p[k_p]}.
```

Do pilot chỉ chiếm một số subcarrier, nội suy tuyến tính các giá trị LS để thu được `H_est` trên toàn bộ `NFFT` subcarrier. Hàm `estimate_channel_ls` nhận `Y`, giá trị pilot đã phát, chỉ số pilot theo thứ tự FFT MATLAB chưa dịch (`fft` output), và `NFFT`. Hàm đổi trục tần số sang thứ tự `fftshift` để nội suy theo thứ tự tần số, rồi đổi kết quả về thứ tự FFT ban đầu. Dùng `H_est` thay cho kênh thật trong bộ cân bằng.

```matlab
H_est = estimate_channel_ls(Y, pilot_symbols, pilot_indices, NFFT);
```

`pilot_indices` phải là chỉ số MATLAB (từ 1 đến `NFFT`) ứng với các vị trí pilot trong `Y`; `pilot_symbols` chứa các giá trị pilot đã biết theo cùng thứ tự.

## 5. Tham số mô phỏng ban đầu

| Tham số | Giá trị đề xuất |
|---|---:|
| Điều chế | QPSK Gray |
| `NFFT` | 64 |
| Subcarrier dữ liệu | 48 |
| Subcarrier pilot | 4 |
| CP | 16 mẫu |
| Số tap kênh `L_h` | 10 |
| Mô hình tap | Rayleigh phức độc lập |
| Chuẩn hóa kênh | `E{sum(abs(h).^2)} = 1` |
| `Eb/N0` | `0:2:20` dB |
| CSI | Perfect CSI |
| Số bit mỗi điểm | Tối thiểu `1e5`, tăng nếu chưa đủ lỗi |

Các vị trí data, pilot, DC và guard subcarrier phải được khai báo một lần bằng các vector chỉ số và dùng thống nhất ở cả bộ phát lẫn bộ thu. Pilot được giữ trong cấu trúc frame để tương thích với mô hình OFDM hiện có; trong phạm vi bắt buộc, đáp ứng kênh vẫn được lấy trực tiếp từ mô phỏng thay vì ước lượng từ pilot.

## 6. Nguyên tắc mô phỏng công bằng

Tại mỗi giá trị `Eb/N0` và mỗi lần thử:

1. Tạo một chuỗi bit và một symbol OFDM duy nhất.
2. Tạo một hiện thực kênh `h[n]` và chuẩn hóa công suất kênh.
3. Tạo một vector nhiễu AWGN duy nhất.
4. Dùng cùng tín hiệu thu cho cả ba nhánh No-EQ, ZF và MMSE.
5. Chỉ thay đổi thuật toán cân bằng; không tạo lại dữ liệu, kênh hoặc nhiễu giữa các nhánh.

Cần ghi rõ quy ước chuyển đổi giữa `Eb/N0`, năng lượng symbol QPSK, công suất tín hiệu miền thời gian, số subcarrier hoạt động và overhead của CP. Không được gắn nhãn trục `Eb/N0` nếu chương trình thực tế chỉ quét phương sai nhiễu mà chưa thực hiện chuyển đổi tương ứng.

## 7. Kịch bản kiểm thử

### 7.1. Kiểm thử cơ bản

- Không có kênh đa đường, không có nhiễu: bit thu phải giống bit phát.
- Có kênh đa đường, không có nhiễu, CP đủ dài: ZF phải khôi phục dữ liệu với sai số số học rất nhỏ.
- Có AWGN nhưng không có fading: BER mô phỏng QPSK phải có xu hướng phù hợp với lý thuyết AWGN.

### 7.2. Thí nghiệm chính

Với kênh Rayleigh đa đường và AWGN, đo đồng thời:

- `BER_NoEQ`;
- `BER_ZF`;
- `BER_MMSE`.

Kỳ vọng:

- Không cân bằng có BER lớn do chòm sao bị suy hao và xoay pha khác nhau trên từng subcarrier.
- ZF cải thiện rõ so với không cân bằng nhưng bị khuếch đại nhiễu tại deep fade.
- MMSE thường có BER thấp hơn ZF ở vùng `Eb/N0` thấp và trung bình.
- Khi `Eb/N0` lớn, kết quả ZF và MMSE tiến gần nhau.

### 7.3. Thí nghiệm minh họa tùy chọn

Giảm CP sao cho `NCP < L_h - 1` để minh họa rằng khi điều kiện CP bị vi phạm, mô hình one-tap trên từng subcarrier không còn chính xác và cả ZF lẫn MMSE đều suy giảm.

## 8. Kết quả cần xuất

Tối thiểu phải có:

1. Một đồ thị BER theo `Eb/N0` chứa ba đường No-EQ, ZF và MMSE.
2. Giản đồ chòm sao của tín hiệu:
   - trước cân bằng;
   - sau ZF;
   - sau MMSE.
3. Đồ thị độ lớn đáp ứng tần số `|H[k]|` của một hiện thực kênh đại diện.
4. Bảng tham số mô phỏng.
5. Nhận xét định lượng tại một số điểm `Eb/N0`, không chỉ nhận xét hình dạng đồ thị.

## 9. Cấu trúc thư mục dự kiến

```text
project/
|-- README.md
|-- docs/
|   `-- spec.txt
|-- src/
|   |-- main_ofdm_equalization.m
|   |-- functions/
|   |   |-- generate_ofdm_bits.m
|   |   |-- qpsk_modulate.m
|   |   |-- map_ofdm_subcarriers.m
|   |   |-- ofdm_ifft.m
|   |   |-- add_cyclic_prefix.m
|   |   |-- serialize_ofdm_symbols.m
|   |   |-- ofdm_transmitter.m
|   |   |-- remove_cyclic_prefix.m
|   |   |-- ofdm_fft.m
|   |   |-- qpsk_demodulate.m
|   |   |-- channel_frequency_response.m
|   |   |-- estimate_channel_ls.m
|   |   `-- zf_equalizer.m
|   `-- tests/
|       `-- ex1.m
|-- results/
|   |-- figures/
|   `-- data/
`-- report/
```

Tên file có thể thay đổi trong quá trình triển khai, nhưng phần tạo dữ liệu, OFDM, kênh, cân bằng và đánh giá BER nên được tách rõ để dễ kiểm thử.

## 10. Tiêu chí hoàn thành

Project được xem là hoàn thành khi:

- Chuỗi phát-thu OFDM chạy đúng với CP đủ dài.
- Cả ba nhánh No-EQ, ZF và MMSE dùng chung dữ liệu/kênh/nhiễu.
- Công thức ZF và MMSE được cài đặt đúng và ổn định số.
- BER giảm hợp lý khi `Eb/N0` tăng.
- Đồ thị và bảng kết quả có đầy đủ đơn vị, chú thích và tham số.
- Báo cáo giải thích được nguyên nhân ZF khuếch đại nhiễu và lý do MMSE cải thiện hiệu năng.
- Mã nguồn có thể chạy lại để tái tạo toàn bộ kết quả trong báo cáo.

## 11. Sản phẩm bàn giao

- Mã nguồn MATLAB hoàn chỉnh.
- File dữ liệu kết quả hoặc cấu hình ngẫu nhiên để tái lập mô phỏng.
- Các hình BER, constellation và đáp ứng kênh.
- Báo cáo Word/PDF.
- Slide thuyết trình và chương trình demo.
