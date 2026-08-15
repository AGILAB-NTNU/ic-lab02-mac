import collections
import random


def generate_test_vectors(num_operations=500, depth=8):
    # 使用雙端佇列 (deque) 作為 Golden Model
    golden_fifo = collections.deque()

    with open("input_vectors.hex", "w") as f_in, open(
        "golden_outputs.hex", "w"
    ) as f_gold:
        for i in range(num_operations):
            # 1. 隨機決定 wr_en 與 rd_en (測試所有組合: 00, 01, 10, 11)
            wr_en = 1 if random.random() < 0.55 else 0
            rd_en = 1 if random.random() < 0.45 else 0
            din = random.randint(0, 0xFFFFFFFF)

            # 2. 判斷實際硬體是否允許寫入與讀出
            is_full = len(golden_fifo) == depth
            is_empty = len(golden_fifo) == 0

            actual_write = wr_en and not is_full
            actual_read = rd_en and not is_empty

            # 3. 更新 Golden Model
            if actual_read:
                expected_dout = golden_fifo.popleft()
                # 寫入預期產生的金標資料 (32-bit, 8碼 HEX)
                f_gold.write(f"{expected_dout:08X}\n")

            # 再處理寫入
            if actual_write:
                golden_fifo.append(din)

            # 4. 寫入輸入向量檔 (格式: wr_en rd_en din_hex)
            f_in.write(f"{wr_en} {rd_en} {din:08X}\n")

        # 額外階段：強迫清空 FIFO，確保把剩餘資料全部輸出完畢
        while len(golden_fifo) > 0:
            wr_en = 0
            rd_en = 1
            din = 0

            expected_dout = golden_fifo.popleft()
            f_gold.write(f"{expected_dout:08X}\n")
            f_in.write(f"{wr_en} {rd_en} {din:08X}\n")

    print(f"測試向量已生成！包含 {num_operations} 筆隨機操作 + 尾端清空操作。")


if __name__ == "__main__":
    generate_test_vectors()
