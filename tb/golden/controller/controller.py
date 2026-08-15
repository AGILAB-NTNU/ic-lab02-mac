import random

# 參數設定 (Parameters)
NUM_RANDOM_CYCLES = 1000  # 隨機測試的總時脈週期數
SEED = 12345  # 隨機數種子碼，確保每次產生的測試向量可重複驗證 (Deterministic)

INPUT_FILE = "controller_input_vectors.hex"  # 輸出的 DUT 測試向量檔名
GOLDEN_FILE = "controller_golden_outputs.hex"  # 輸出的 Golden 正確答案檔名

# 控制器 Golden 模型 (Controller Golden Model)
# 此函數模擬 RTL 組合邏輯與狀態計數器的行為：
# 1. 計算當前週期的控制輸出訊號 (o_in_fifo_rden, o_calc_en 等)
# 2. 計算下一個時脈週期計數器 (calc_count) 的狀態
def controller_model(
    a_empty,
    b_empty,
    a_data_valid,
    b_data_valid,
    out_full,
    mac_result_valid,
    calc_count,
):

    # 雙通道輸入資料皆有效 (Input Data Valid)
    # 只有當 FIFO A 與 FIFO B 的資料均準備好時才為 True
    input_data_valid = a_data_valid and b_data_valid

    # MAC 結果接收準備訊號 (MAC Ready)
    # 只要輸出 FIFO 未滿，代表後級可接收 MAC 結果
    mac_result_ready = not out_full

    # 輸出 FIFO 寫入致能 (Output FIFO Write Enable)
    # 當 MAC 結果有效且輸出 FIFO 還有空間時觸發寫入
    out_fifo_wren = mac_result_valid and (not out_full)

    # MAC 計算致能 (MAC Calculation Enable)
    # 輸入資料有效，且當前無有效的 MAC 計算結果等待讀取時開始計算
    calc_en = input_data_valid and (not mac_result_valid)

    # 累加器重置訊號 (Accumulator Reset)
    # 開始進行新一輪 MAC 計算 (calc_count == 0) 時清空累加器
    acc_rst = calc_en and (calc_count == 0)

    # 輸入 FIFO 讀出致能 (Input FIFO Read Enable)
    in_fifo_rden = (
        (not a_empty)
        and (not b_empty)
        and (not out_full)
        and (not mac_result_valid)
        and not (input_data_valid and (calc_count == 9))
    )

    # 時序邏輯計數器更新 (Sequential counter update)
    next_calc_count = calc_count

    if calc_en:
        if calc_count == 9:
            next_calc_count = 0  # 累加達到 10 次 (0~9) 後重置歸零
        else:
            next_calc_count = calc_count + 1  # 遞增計數

    # 回傳輸出結果與下一個狀態 (轉換為 0/1 整型)
    return (
        int(in_fifo_rden),
        int(calc_en),
        int(acc_rst),
        int(out_fifo_wren),
        int(mac_result_ready),
        next_calc_count,
    )

# 產生定向測試向量 (Generate deterministic directed tests)
# 涵蓋各種特定的邊界條件 (Corner Cases) 與臨界情境
def generate_directed_tests():
    tests = []

    # 測試格式為 Tuple:
    # (a_empty, b_empty, a_data_valid, b_data_valid, out_full, mac_result_valid)

    # 1. 系統閒置 (Everything idle)
    tests.append((1, 1, 0, 0, 0, 0))

    # 2. FIFO 非空但資料尚未有效 (A/B not empty but data not valid yet)
    tests.append((0, 0, 0, 0, 0, 0))

    # 3. 僅通道 A 資料有效 (Only A data valid)
    tests.append((0, 0, 1, 0, 0, 0))

    # 4. 僅通道 B 資料有效 (Only B data valid)
    tests.append((0, 0, 0, 1, 0, 0))

    # 5. 兩通道資料皆有效 -> 開始運算 (Both data valid -> calculation)
    tests.append((0, 0, 1, 1, 0, 0))

    # 6. 通道 A 為空 (A empty)
    tests.append((1, 0, 1, 1, 0, 0))

    # 7. 通道 B 為空 (B empty)
    tests.append((0, 1, 1, 1, 0, 0))

    # 8. 輸出 FIFO 滿載 (Output FIFO full)
    tests.append((0, 0, 1, 1, 1, 0))

    # 9. MAC 運算結果有效 (MAC result valid)
    tests.append((0, 0, 1, 1, 0, 1))

    # 10. MAC 結果有效且輸出 FIFO 滿載 (MAC result valid + output FIFO full)
    tests.append((0, 0, 1, 1, 1, 1))

    # 11. MAC 結果有效但前端無輸入資料 (MAC result valid but no input data)
    tests.append((0, 0, 0, 0, 0, 1))

    # 12. FIFO 為空且 MAC 結果有效 (Empty + MAC result valid)
    tests.append((1, 1, 0, 0, 0, 1))

    return tests

# 主程式：生成所有測試向量並寫入檔案 (Main Vector Generation)
def generate_vectors():
    # 設定隨機數種子以保證可重複性
    random.seed(SEED)

    input_vectors = []
    golden_vectors = []

    # 1. 加入定向測試向量 (Directed tests)
    input_vectors.extend(generate_directed_tests())

   
    # 2. 加入隨機測試向量 (Random tests)
    for _ in range(NUM_RANDOM_CYCLES):
        a_empty = random.randint(0, 1)
        b_empty = random.randint(0, 1)

        a_data_valid = random.randint(0, 1)
        b_data_valid = random.randint(0, 1)

        out_full = random.randint(0, 1)
        mac_result_valid = random.randint(0, 1)

        input_vectors.append((
            a_empty,
            b_empty,
            a_data_valid,
            b_data_valid,
            out_full,
            mac_result_valid,
        ))

    # 3. 逐筆計算 Golden 輸出並寫入檔案
    calc_count = 0  # 初始化內置運算計數器

    with (
        open(INPUT_FILE, "w") as f_in,
        open(GOLDEN_FILE, "w") as f_gold,
    ):
        for vector in input_vectors:
            (
                a_empty,
                b_empty,
                a_data_valid,
                b_data_valid,
                out_full,
                mac_result_valid,
            ) = vector

            # 透過 Golden Model 計算目前狀態下的正確輸出
            (
                in_fifo_rden,
                calc_en,
                acc_rst,
                out_fifo_wren,
                mac_result_ready,
                next_calc_count,
            ) = controller_model(
                a_empty,
                b_empty,
                a_data_valid,
                b_data_valid,
                out_full,
                mac_result_valid,
                calc_count,
            )

            # 寫入輸入測試向量檔 (controller_input_vectors.hex)
            # 格式：a_empty b_empty a_valid b_valid out_full mac_valid
            f_in.write(
                f"{a_empty} "
                f"{b_empty} "
                f"{a_data_valid} "
                f"{b_data_valid} "
                f"{out_full} "
                f"{mac_result_valid}\n"
            )

            # 寫入 Golden 正確答案檔 (controller_golden_outputs.hex)
            # 格式：rden calc_en acc_rst wren ready
            f_gold.write(
                f"{in_fifo_rden} "
                f"{calc_en} "
                f"{acc_rst} "
                f"{out_fifo_wren} "
                f"{mac_result_ready}\n"
            )

            # 推進狀態計數器至下一個週期
            calc_count = next_calc_count

    # 4. 顯示產生完成摘要報告
    print("==============================================")
    print(" Controller Test Vector Generation Complete")
    print("==============================================")
    print(f"Random cycles : {NUM_RANDOM_CYCLES}")
    print(f"Directed tests: {len(generate_directed_tests())}")
    print(f"Total cycles  : {len(input_vectors)}")
    print(f"Random seed   : {SEED}")
    print(f"Input file    : {INPUT_FILE}")
    print(f"Golden file   : {GOLDEN_FILE}")
    print("==============================================")

if __name__ == "__main__":
    generate_vectors()
